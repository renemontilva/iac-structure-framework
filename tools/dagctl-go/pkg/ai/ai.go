package ai

import (
	"context"
	"fmt"
)

type Advisor interface {
	Suggest(ctx context.Context, logText string, layer string, action string) (string, error)
}

type advisor struct{}

func New() *advisor { return &advisor{} }

func (a *advisor) Suggest(ctx context.Context, logText string, layer string, action string) (string, error) {
	// Placeholder: no external dependency to keep build simple
	return fmt.Sprintf("AI assistance disabled in this build. Logs for %s/%s analyzed locally. Common issues: missing providers, wrong tfvars path, remote state not found.", layer, action), nil
}

