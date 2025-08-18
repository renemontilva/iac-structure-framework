package graph

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// Graph is a simple DAG of layer paths
type Graph struct {
	nodes map[string]struct{}
	edges map[string]map[string]struct{}
}

func Build(ctx context.Context, workspace string) (*Graph, error) {
	g := &Graph{nodes: map[string]struct{}{}, edges: map[string]map[string]struct{}{}}
	root := filepath.Clean(workspace)

	// Discover layer directories with numeric prefixes
	prefixRE := regexp.MustCompile(`^(?:\d{2}-[a-z0-9-]+)(?:/\d{2}-[a-z0-9-]+)*$`)
	var layerDirs []string
	walkFn := func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}
		// Only consider first three levels
		parts := strings.Split(rel, string(filepath.Separator))
		if len(parts) > 3 {
			return filepath.SkipDir
		}
		joined := strings.Join(parts, "/")
		if prefixRE.MatchString(joined) {
			layerDirs = append(layerDirs, path)
		}
		return nil
	}
	for _, top := range []string{
		filepath.Join(root, "00-governance"),
		filepath.Join(root, "01-core"),
		filepath.Join(root, "02-services"),
		filepath.Join(root, "03-applications"),
	} {
		_ = filepath.WalkDir(top, walkFn)
	}

	for _, d := range layerDirs {
		g.addNode(d)
	}

	// Naive dependency inference: parent directory implies order; plus terraform_remote_state scan
	for _, d := range layerDirs {
		// parent hierarchy edges (e.g., 01-core/01-networking depends on 00-governance)
		if strings.Contains(d, string(filepath.Separator)) {
			// assume anything in 01-core depends on 00-governance
			if strings.Contains(d, string(filepath.Separator)+"01-core"+string(filepath.Separator)) || strings.HasSuffix(d, string(filepath.Separator)+"01-core") {
				gov := filepath.Join(root, "00-governance")
				if g.hasNodePathPrefix(gov) {
					g.addEdge(gov, d)
				}
			}
		}
		// terraform_remote_state scan
		deps, _ := inferTerraformRemoteStateDeps(d, root)
		for _, dep := range deps {
			if g.hasNodePathPrefix(dep) {
				g.addEdge(dep, d)
			}
		}
	}

	return g, nil
}

func (g *Graph) addNode(n string) {
	if _, ok := g.nodes[n]; !ok {
		g.nodes[n] = struct{}{}
	}
	if _, ok := g.edges[n]; !ok {
		g.edges[n] = map[string]struct{}{}
	}
}

func (g *Graph) addEdge(from, to string) {
	g.addNode(from)
	g.addNode(to)
	if _, ok := g.edges[from]; !ok {
		g.edges[from] = map[string]struct{}{}
	}
	g.edges[from][to] = struct{}{}
}

func (g *Graph) hasNodePathPrefix(prefix string) bool {
	for n := range g.nodes {
		if strings.HasPrefix(n, prefix) {
			return true
		}
	}
	return false
}

func (g *Graph) Nodes() []string {
	out := make([]string, 0, len(g.nodes))
	for n := range g.nodes {
		out = append(out, n)
	}
	sort.Strings(out)
	return out
}

func (g *Graph) EdgeCount() int {
	c := 0
	for _, m := range g.edges {
		c += len(m)
	}
	return c
}

func (g *Graph) ValidateAcyclic() error {
	_, err := g.TopologicalOrder()
	return err
}

func (g *Graph) TopologicalOrder() ([]string, error) {
	// Kahn's algorithm
	inDeg := map[string]int{}
	for n := range g.nodes {
		inDeg[n] = 0
	}
	for u, vs := range g.edges {
		for v := range vs {
			inDeg[v]++
		}
		// ensure u present
		_ = inDeg[u]
	}
	var q []string
	for n, d := range inDeg {
		if d == 0 {
			q = append(q, n)
		}
	}
	sort.Strings(q)
	var order []string
	for len(q) > 0 {
		n := q[0]
		q = q[1:]
		order = append(order, n)
		for v := range g.edges[n] {
			inDeg[v]--
			if inDeg[v] == 0 {
				q = append(q, v)
				sort.Strings(q)
			}
		}
	}
	if len(order) != len(g.nodes) {
		return nil, fmt.Errorf("graph has cycles or disconnected issues: produced %d of %d", len(order), len(g.nodes))
	}
	return order, nil
}

// Waves returns groups of nodes that can run concurrently in order
func (g *Graph) Waves() [][]string {
	inDeg := map[string]int{}
	for n := range g.nodes {
		inDeg[n] = 0
	}
	for _, vs := range g.edges {
		for v := range vs {
			inDeg[v]++
		}
	}
	var waves [][]string
	for {
		var layer []string
		for n, d := range inDeg {
			if d == 0 {
				layer = append(layer, n)
			}
		}
		if len(layer) == 0 {
			break
		}
		sort.Strings(layer)
		waves = append(waves, layer)
		for _, n := range layer {
			inDeg[n] = -1 // consumed
			for v := range g.edges[n] {
				inDeg[v]--
			}
		}
	}
	return waves
}

func (g *Graph) ToMermaid() string {
	var b strings.Builder
	b.WriteString("flowchart TD\n")
	// nodes
	for _, n := range g.Nodes() {
		b.WriteString(fmt.Sprintf("  n%d[%s]\n", hash(n), escapeNodeLabel(n)))
	}
	// edges
	for u, vs := range g.edges {
		for v := range vs {
			b.WriteString(fmt.Sprintf("  n%d --> n%d\n", hash(u), hash(v)))
		}
	}
	return b.String()
}

func (g *Graph) ToDOT() string {
	var b strings.Builder
	b.WriteString("digraph G {\n")
	for _, n := range g.Nodes() {
		b.WriteString(fmt.Sprintf("  \"%s\";\n", n))
	}
	for u, vs := range g.edges {
		for v := range vs {
			b.WriteString(fmt.Sprintf("  \"%s\" -> \"%s\";\n", u, v))
		}
	}
	b.WriteString("}\n")
	return b.String()
}

func escapeNodeLabel(s string) string {
	return strings.ReplaceAll(s, "\"", "'")
}

func hash(s string) uint32 {
	// simple FNV-1a 32
	var h uint32 = 2166136261
	for i := 0; i < len(s); i++ {
		h ^= uint32(s[i])
		h *= 16777619
	}
	return h
}

func inferTerraformRemoteStateDeps(layerDir, root string) ([]string, error) {
	var deps []string
	_ = filepath.WalkDir(layerDir, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		if !strings.HasSuffix(path, ".tf") {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		content := string(b)
		// look for keys like 01-core/01-networking and 00-governance
		keyRE := regexp.MustCompile(`key\s*=\s*\"[^\"]+\"`)
		for _, m := range keyRE.FindAllString(content, -1) {
			val := strings.TrimSpace(strings.Trim(strings.SplitN(m, "=", 2)[1], " \""))
			if strings.Contains(val, "00-governance") {
				deps = append(deps, filepath.Join(root, "00-governance"))
			}
			if strings.Contains(val, "01-core/01-networking") {
				deps = append(deps, filepath.Join(root, "01-core", "01-networking"))
			}
			if strings.Contains(val, "01-core/02-security") {
				deps = append(deps, filepath.Join(root, "01-core", "02-security"))
			}
		}
		return nil
	})
	return unique(deps), nil
}

func unique(in []string) []string {
	m := map[string]struct{}{}
	var out []string
	for _, s := range in {
		if _, ok := m[s]; !ok {
			m[s] = struct{}{}
			out = append(out, s)
		}
	}
	return out
}