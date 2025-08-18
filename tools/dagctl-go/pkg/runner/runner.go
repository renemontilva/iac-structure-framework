package runner

import (
	"bufio"
	"context"
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/pterm/pterm"
)

type Action string

const (
	ActionPlan    Action = "plan"
	ActionApply   Action = "apply"
	ActionDestroy Action = "destroy"
)

type Advisor interface {
	Suggest(ctx context.Context, logText string, layer string, action string) (string, error)
}

type Options struct {
	Parallelism int
	Advisor     Advisor
}

// Run executes waves of layers with limited parallelism and progress
func Run(ctx context.Context, waves [][]string, environment string, action Action, opts Options) error {
	if opts.Parallelism <= 0 {
		opts.Parallelism = 3
	}
	pterm.Info.Printfln("Starting %s for %d waves", action, len(waves))
	for i, wave := range waves {
		pterm.DefaultSection.Println(fmt.Sprintf("Wave %d", i+1))
		bar, _ := pterm.DefaultProgressbar.WithTotal(len(wave)).WithTitle(fmt.Sprintf("%s", action)).Start()
		sem := make(chan struct{}, opts.Parallelism)
		var wg sync.WaitGroup
		var firstErr error
		var mu sync.Mutex
		for _, layerPath := range wave {
			wg.Add(1)
			sem <- struct{}{}
			go func(lp string) {
				defer wg.Done()
				defer func() { <-sem }()
				t0 := time.Now()
				ok, logs := runTerraform(ctx, lp, environment, action)
				elapsed := time.Since(t0)
				if ok {
					bar.Increment()
					pterm.Success.Printfln("[%s] %s succeeded in %s", action, lp, elapsed)
					return
				}
				pterm.Error.Printfln("[%s] %s failed in %s", action, lp, elapsed)
				if opts.Advisor != nil {
					advice, err := opts.Advisor.Suggest(ctx, logs, lp, string(action))
					if err == nil && strings.TrimSpace(advice) != "" {
						pterm.Warning.Println("AI advice:")
						pterm.Println(advice)
					}
				}
				mu.Lock()
				if firstErr == nil {
					firstErr = fmt.Errorf("layer %s failed", lp)
				}
				mu.Unlock()
			}(layerPath)
		}
		wg.Wait()
		bar.Stop()
		if firstErr != nil {
			return firstErr
		}
	}
	return nil
}

func runTerraform(ctx context.Context, layerPath, environment string, action Action) (bool, string) {
	// Compose command
	cmdStr := fmt.Sprintf("bash -lc 'cd %s && terraform init -input=false -no-color && terraform %s -input=false -no-color %s -var-file=environments/%s.tfvars'",
		filepath.Clean(layerPath), action, autoApprove(action), environment)
	cmd := exec.CommandContext(ctx, "bash", "-lc", cmdStr)
	stdout, _ := cmd.StdoutPipe()
	cmd.Stderr = cmd.Stdout
	if err := cmd.Start(); err != nil {
		return false, err.Error()
	}
	var b strings.Builder
	s := bufio.NewScanner(stdout)
	for s.Scan() {
		line := s.Text()
		b.WriteString(line)
		b.WriteString("\n")
		pterm.Println(line)
	}
	_ = cmd.Wait()
	return cmd.ProcessState.Success(), b.String()
}

func autoApprove(a Action) string {
	if a == ActionApply || a == ActionDestroy {
		return "-auto-approve"
	}
	return ""
}