package main

import (
	"context"
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"dagctl/pkg/ai"
	"dagctl/pkg/graph"
	"dagctl/pkg/runner"
)

func main() {
	root := &cobra.Command{Use: "dagctl", Short: "DAG-based Terraform orchestrator (Go)", SilenceUsage: true}

	var workspace string
	root.PersistentFlags().StringVar(&workspace, "workspace", ".", "Workspace root to scan")

	root.AddCommand(newValidateCmd(&workspace))
	root.AddCommand(newGraphCmd(&workspace))
	root.AddCommand(newPlanCmd(&workspace))
	root.AddCommand(newApplyCmd(&workspace))
	root.AddCommand(newDestroyCmd(&workspace))

	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func newValidateCmd(workspace *string) *cobra.Command {
	cmd := &cobra.Command{Use: "validate", Short: "Validate DAG (no cycles) and show counts"}
	cmd.RunE = func(cmd *cobra.Command, args []string) error {
		g, err := graph.Build(cmd.Context(), *workspace)
		if err != nil {
			return err
		}
		if err := g.ValidateAcyclic(); err != nil {
			return err
		}
		fmt.Printf("Nodes: %d, Edges: %d\n", len(g.Nodes()), g.EdgeCount())
		return nil
	}
	return cmd
}

func newGraphCmd(workspace *string) *cobra.Command {
	var format string
	cmd := &cobra.Command{Use: "graph", Short: "Print DAG as mermaid or dot"}
	cmd.Flags().StringVar(&format, "format", "mermaid", "Output format: mermaid|dot|list")
	cmd.RunE = func(cmd *cobra.Command, args []string) error {
		g, err := graph.Build(cmd.Context(), *workspace)
		if err != nil {
			return err
		}
		switch format {
		case "mermaid":
			fmt.Println(g.ToMermaid())
		case "dot":
			fmt.Println(g.ToDOT())
		case "list":
			order, err := g.TopologicalOrder()
			if err != nil {
				return err
			}
			for i, n := range order {
				fmt.Printf("%02d: %s\n", i+1, n)
			}
		default:
			return fmt.Errorf("unknown format: %s", format)
		}
		return nil
	}
	return cmd
}

func newPlanCmd(workspace *string) *cobra.Command {
	var env string
	var parallel int
	var useAI bool
	cmd := &cobra.Command{Use: "plan", Short: "Run terraform plan across DAG"}
	cmd.Flags().StringVar(&env, "environment", "dev", "Environment name (tfvars)")
	cmd.Flags().IntVar(&parallel, "parallel", 3, "Parallelism per wave")
	cmd.Flags().BoolVar(&useAI, "ai", true, "Enable AI advisor on failures")
	cmd.RunE = func(cmd *cobra.Command, args []string) error {
		return runOrchestrator(cmd.Context(), *workspace, env, parallel, runner.ActionPlan, useAI)
	}
	return cmd
}

func newApplyCmd(workspace *string) *cobra.Command {
	var env string
	var parallel int
	var useAI bool
	cmd := &cobra.Command{Use: "apply", Short: "Run terraform apply across DAG"}
	cmd.Flags().StringVar(&env, "environment", "dev", "Environment name (tfvars)")
	cmd.Flags().IntVar(&parallel, "parallel", 3, "Parallelism per wave")
	cmd.Flags().BoolVar(&useAI, "ai", true, "Enable AI advisor on failures")
	cmd.RunE = func(cmd *cobra.Command, args []string) error {
		return runOrchestrator(cmd.Context(), *workspace, env, parallel, runner.ActionApply, useAI)
	}
	return cmd
}

func newDestroyCmd(workspace *string) *cobra.Command {
	var env string
	var parallel int
	var useAI bool
	cmd := &cobra.Command{Use: "destroy", Short: "Run terraform destroy across DAG (reverse order)"}
	cmd.Flags().StringVar(&env, "environment", "dev", "Environment name (tfvars)")
	cmd.Flags().IntVar(&parallel, "parallel", 3, "Parallelism per wave")
	cmd.Flags().BoolVar(&useAI, "ai", true, "Enable AI advisor on failures")
	cmd.RunE = func(cmd *cobra.Command, args []string) error {
		return runOrchestrator(cmd.Context(), *workspace, env, parallel, runner.ActionDestroy, useAI)
	}
	return cmd
}

func runOrchestrator(ctx context.Context, workspace, environment string, parallel int, action runner.Action, useAI bool) error {
	g, err := graph.Build(ctx, workspace)
	if err != nil {
		return err
	}
	if err := g.ValidateAcyclic(); err != nil {
		return err
	}
	waves := g.Waves()
	var advisor ai.Advisor
	if useAI {
		advisor = ai.New()
	}
	return runner.Run(ctx, waves, environment, action, runner.Options{Parallelism: parallel, Advisor: advisor})
}

