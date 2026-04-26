package runtime

import (
	"context"

	v1beta1 "github.com/hiclaw/hiclaw-controller/api/v1beta1"
)

// WorkerRuntime defines the interface for different Worker runtime implementations.
type WorkerRuntime interface {
	// Create initializes a new Worker instance (container, Matrix account, config files).
	Create(ctx context.Context, worker *v1beta1.Worker) error

	// Start starts an existing Worker instance.
	Start(ctx context.Context, worker *v1beta1.Worker) error

	// Stop stops a running Worker instance gracefully.
	Stop(ctx context.Context, worker *v1beta1.Worker) error

	// HealthCheck performs a health check on the Worker.
	HealthCheck(ctx context.Context, worker *v1beta1.Worker) (HealthStatus, error)

	// Update updates the Worker configuration (model, skills, mcpServers, etc.).
	Update(ctx context.Context, worker *v1beta1.Worker) error

	// Delete removes the Worker instance and cleans up resources.
	Delete(ctx context.Context, worker *v1beta1.Worker) error
}

// HealthStatus represents the health check result.
type HealthStatus struct {
	Healthy   bool   `json:"healthy"`
	Message   string `json:"message,omitempty"`
	StartTime string `json:"startTime,omitempty"`
	Uptime    string `json:"uptime,omitempty"`
}

// RuntimeType is the type identifier for a Worker runtime.
type RuntimeType string

const (
	RuntimeOpenClaw RuntimeType = "openclaw"
	RuntimeCoPaw    RuntimeType = "copaw"
	RuntimeFastClaw RuntimeType = "fastclaw"
	RuntimeZeroClaw RuntimeType = "zeroclaw"
	RuntimeNanoClaw RuntimeType = "nanoclaw"
	RuntimeOpenFang RuntimeType = "openfang"
)

// RuntimeRegistry manages different Worker runtime implementations.
type RuntimeRegistry struct {
	runtimes map[RuntimeType]WorkerRuntime
}

// NewRuntimeRegistry creates a new RuntimeRegistry.
func NewRuntimeRegistry() *RuntimeRegistry {
	return &RuntimeRegistry{
		runtimes: make(map[RuntimeType]WorkerRuntime),
	}
}

// Register registers a Worker runtime implementation.
func (r *RuntimeRegistry) Register(runtimeType RuntimeType, runtime WorkerRuntime) {
	r.runtimes[runtimeType] = runtime
}

// Get retrieves a Worker runtime by type.
func (r *RuntimeRegistry) Get(runtimeType RuntimeType) (WorkerRuntime, error) {
	runtime, exists := r.runtimes[runtimeType]
	if !exists {
		return nil, &UnsupportedRuntimeError{RuntimeType: string(runtimeType)}
	}
	return runtime, nil
}

// List returns all registered runtime types.
func (r *RuntimeRegistry) List() []RuntimeType {
	types := make([]RuntimeType, 0, len(r.runtimes))
	for t := range r.runtimes {
		types = append(types, t)
	}
	return types
}

// UnsupportedRuntimeError is returned when an unsupported runtime type is requested.
type UnsupportedRuntimeError struct {
	RuntimeType string
}

func (e *UnsupportedRuntimeError) Error() string {
	return "unsupported runtime type: " + e.RuntimeType
}
