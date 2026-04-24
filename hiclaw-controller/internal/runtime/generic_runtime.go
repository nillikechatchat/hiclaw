package runtime

import (
	"context"
	"encoding/json"
	"fmt"

	v1beta1 "github.com/hiclaw/hiclaw-controller/api/v1beta1"
	"github.com/hiclaw/hiclaw-controller/internal/executor"
)

// GenericRuntime is a generic Worker runtime implementation that uses shell scripts.
// It works for openclaw, copaw, fastclaw, and other runtimes that follow the standard pattern.
type GenericRuntime struct {
	Executor *executor.Shell
	Packages *executor.PackageResolver
}

// Create implements WorkerRuntime.Create.
func (r *GenericRuntime) Create(ctx context.Context, worker *v1beta1.Worker) error {
	if worker.Spec.Package != "" {
		extractedDir, err := r.Packages.ResolveAndExtract(ctx, worker.Spec.Package, worker.Name)
		if err != nil {
			return fmt.Errorf("package resolve/extract failed: %w", err)
		}
		if extractedDir != "" {
			if err := r.Packages.DeployToMinIO(ctx, extractedDir, worker.Name, false); err != nil {
				return fmt.Errorf("package deploy failed: %w", err)
			}
		}
	}

	// Write inline configs if specified
	if worker.Spec.Identity != "" || worker.Spec.Soul != "" || worker.Spec.Agents != "" {
		agentDir := fmt.Sprintf("/root/hiclaw-fs/agents/%s", worker.Name)
		if err := executor.WriteInlineConfigs(agentDir, worker.Spec.Runtime, worker.Spec.Identity, worker.Spec.Soul, worker.Spec.Agents); err != nil {
			return fmt.Errorf("write inline configs failed: %w", err)
		}
	}

	// Build script arguments
	args := buildWorkerArgs(worker)

	_, err := r.Executor.Run(ctx,
		"/opt/hiclaw/agent/skills/worker-management/scripts/create-worker.sh",
		args...,
	)
	if err != nil {
		return fmt.Errorf("create-worker.sh failed: %w", err)
	}

	return nil
}

// Start implements WorkerRuntime.Start.
func (r *GenericRuntime) Start(ctx context.Context, worker *v1beta1.Worker) error {
	// For most runtimes, Create already starts the container.
	// This method can be used for explicit start if needed.
	return nil
}

// Stop implements WorkerRuntime.Stop.
func (r *GenericRuntime) Stop(ctx context.Context, worker *v1beta1.Worker) error {
	_, err := r.Executor.RunSimple(ctx,
		"/opt/hiclaw/agent/skills/worker-management/scripts/lifecycle-worker.sh",
		"--action", "stop", "--worker", worker.Name,
	)
	return err
}

// HealthCheck implements WorkerRuntime.HealthCheck.
func (r *GenericRuntime) HealthCheck(ctx context.Context, worker *v1beta1.Worker) (HealthStatus, error) {
	// Check container state via shell script or Docker API
	// For now, return a basic status
	return HealthStatus{
		Healthy: true,
		Message: "Container is running",
	}, nil
}

// Update implements WorkerRuntime.Update.
func (r *GenericRuntime) Update(ctx context.Context, worker *v1beta1.Worker) error {
	// Deploy package if specified
	if worker.Spec.Package != "" {
		extractedDir, err := r.Packages.ResolveAndExtract(ctx, worker.Spec.Package, worker.Name)
		if err != nil {
			return fmt.Errorf("package resolve/extract failed: %w", err)
		}
		if extractedDir != "" {
			if err := r.Packages.DeployToMinIO(ctx, extractedDir, worker.Name, true); err != nil {
				return fmt.Errorf("package deploy failed: %w", err)
			}
		}
	}

	// Write inline configs if specified
	if worker.Spec.Identity != "" || worker.Spec.Soul != "" || worker.Spec.Agents != "" {
		agentDir := fmt.Sprintf("/root/hiclaw-fs/agents/%s", worker.Name)
		if err := executor.WriteInlineConfigs(agentDir, worker.Spec.Runtime, worker.Spec.Identity, worker.Spec.Soul, worker.Spec.Agents); err != nil {
			return fmt.Errorf("write inline configs failed: %w", err)
		}
	}

	// Build script arguments for update
	args := []string{"--name", worker.Name}
	if worker.Spec.Model != "" {
		args = append(args, "--model", worker.Spec.Model)
	}
	if len(worker.Spec.Skills) > 0 {
		args = append(args, "--skills", joinStrings(worker.Spec.Skills))
	}
	if len(worker.Spec.McpServers) > 0 {
		args = append(args, "--mcp-servers", joinStrings(worker.Spec.McpServers))
	}
	if worker.Spec.ChannelPolicy != nil {
		if policyJSON, err := json.Marshal(worker.Spec.ChannelPolicy); err == nil {
			args = append(args, "--channel-policy", string(policyJSON))
		}
	}

	_, err := r.Executor.Run(ctx,
		"/opt/hiclaw/agent/skills/worker-management/scripts/update-worker-config.sh",
		args...,
	)
	if err != nil {
		return fmt.Errorf("update-worker-config.sh failed: %w", err)
	}

	return nil
}

// Delete implements WorkerRuntime.Delete.
func (r *GenericRuntime) Delete(ctx context.Context, worker *v1beta1.Worker) error {
	_, err := r.Executor.RunSimple(ctx,
		"/opt/hiclaw/agent/skills/worker-management/scripts/lifecycle-worker.sh",
		"--action", "delete", "--worker", worker.Name,
	)
	return err
}

// buildWorkerArgs builds command-line arguments for create-worker.sh.
func buildWorkerArgs(worker *v1beta1.Worker) []string {
	args := []string{"--name", worker.Name}

	if worker.Spec.Model != "" {
		args = append(args, "--model", worker.Spec.Model)
	}
	if worker.Spec.Runtime != "" {
		args = append(args, "--runtime", worker.Spec.Runtime)
	}
	if worker.Spec.Image != "" {
		args = append(args, "--image", worker.Spec.Image)
	}
	if len(worker.Spec.Skills) > 0 {
		args = append(args, "--skills", joinStrings(worker.Spec.Skills))
	}
	if len(worker.Spec.McpServers) > 0 {
		args = append(args, "--mcp-servers", joinStrings(worker.Spec.McpServers))
	}
	if worker.Spec.ChannelPolicy != nil {
		if policyJSON, err := json.Marshal(worker.Spec.ChannelPolicy); err == nil {
			args = append(args, "--channel-policy", string(policyJSON))
		}
	}
	// Add runtime-specific config
	if worker.Spec.RuntimeConfig != nil {
		if configJSON, err := json.Marshal(worker.Spec.RuntimeConfig); err == nil {
			args = append(args, "--runtime-config", string(configJSON))
		}
	}

	// Check for team annotations
	if role := worker.Annotations["hiclaw.io/role"]; role != "" {
		args = append(args, "--role", role)
	}
	if team := worker.Annotations["hiclaw.io/team"]; team != "" {
		args = append(args, "--team", team)
	}
	if leader := worker.Annotations["hiclaw.io/team-leader"]; leader != "" {
		args = append(args, "--team-leader", leader)
	}

	return args
}

// joinStrings joins a slice of strings with commas.
func joinStrings(ss []string) string {
	result := ""
	for i, s := range ss {
		if i > 0 {
			result += ","
		}
		result += s
	}
	return result
}
