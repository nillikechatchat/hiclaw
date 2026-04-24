// +k8s:deepcopy-gen=package

package v1beta1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

const (
	GroupName = "hiclaw.io"
	Version   = "v1beta1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Worker represents an AI agent worker in HiClaw.
type Worker struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`
	Spec              WorkerSpec   `json:"spec"`
	Status            WorkerStatus `json:"status,omitempty"`
}

type WorkerSpec struct {
	Model         string                `json:"model"`
	Runtime       string                `json:"runtime,omitempty"` // openclaw | copaw | fastclaw | zeroclaw | nanoclaw | openfang (default: openclaw)
	RuntimeConfig *RuntimeConfigSpec    `json:"runtimeConfig,omitempty"`
	Image         string                `json:"image,omitempty"` // custom Docker image
	Identity      string                `json:"identity,omitempty"`
	Soul          string                `json:"soul,omitempty"`
	Agents        string                `json:"agents,omitempty"`
	Skills        []string              `json:"skills,omitempty"`
	McpServers    []string              `json:"mcpServers,omitempty"`
	Package       string                `json:"package,omitempty"` // file://, http(s)://, nacos://, or packages/{name}.zip URI
	Expose        []ExposePort          `json:"expose,omitempty"`  // ports to expose via Higress gateway
	ChannelPolicy *ChannelPolicySpec    `json:"channelPolicy,omitempty"`
}

// RuntimeConfigSpec defines runtime-specific configuration options.
type RuntimeConfigSpec struct {
	FastClaw  *FastClawConfig  `json:"fastclaw,omitempty"`
	ZeroClaw  *ZeroClawConfig  `json:"zeroclaw,omitempty"`
	NanoClaw  *NanoClawConfig  `json:"nanoclaw,omitempty"`
	OpenFang  *OpenFangConfig  `json:"openfang,omitempty"`
}

// FastClawConfig holds configuration for the fastclaw (Python lightweight) runtime.
type FastClawConfig struct {
	PythonVersion string `json:"pythonVersion,omitempty"` // 3.11 (default) | 3.12
	SDK           string `json:"sdk,omitempty"`           // claude (default) | openai
}

// ZeroClawConfig holds configuration for the zeroclaw (Rust high-performance) runtime.
type ZeroClawConfig struct {
	WasmSupport bool `json:"wasmSupport,omitempty"` // default: false
	Concurrency int  `json:"concurrency,omitempty"` // default: 100, range: 1-10000
}

// NanoClawConfig holds configuration for the nanoclaw (Node.js minimal) runtime.
type NanoClawConfig struct {
	ContainerTimeout int    `json:"containerTimeout,omitempty"` // default: 300 seconds (5 min), range: 60-1800
	Channel          string `json:"channel,omitempty"`          // matrix (default) | whatsapp
}

// OpenFangConfig holds configuration for the openfang (Rust enterprise) runtime.
type OpenFangConfig struct {
	PluginDir     string                    `json:"pluginDir,omitempty"` // default: /app/plugins
	Observability *OpenFangObservability    `json:"observability,omitempty"`
	Security      *OpenFangSecurity         `json:"security,omitempty"`
}

// OpenFangObservability defines observability settings for openfang.
type OpenFangObservability struct {
	Enabled         bool   `json:"enabled,omitempty"`
	TracingEndpoint string `json:"tracingEndpoint,omitempty"`
	MetricsEndpoint string `json:"metricsEndpoint,omitempty"`
}

// OpenFangSecurity defines security settings for openfang.
type OpenFangSecurity struct {
	SMCrypto  bool `json:"smCrypto,omitempty"`  // Enable Chinese commercial cryptographic algorithms
	AuditLog  bool `json:"auditLog,omitempty"`  // Enable audit logging (default: true)
}

// ExposePort defines a container port to expose via the Higress gateway.
type ExposePort struct {
	Port     int    `json:"port"`
	Protocol string `json:"protocol,omitempty"` // http (default) | grpc
}

// ChannelPolicySpec defines additive/subtractive overrides on top of default
// communication policies. Values are Matrix user IDs (@user:domain) or
// short usernames (auto-resolved to full IDs by config generation scripts).
type ChannelPolicySpec struct {
	GroupAllowExtra []string `json:"groupAllowExtra,omitempty"`
	GroupDenyExtra  []string `json:"groupDenyExtra,omitempty"`
	DmAllowExtra    []string `json:"dmAllowExtra,omitempty"`
	DmDenyExtra     []string `json:"dmDenyExtra,omitempty"`
}

type WorkerStatus struct {
	Phase          string              `json:"phase,omitempty"` // Pending/Running/Stopped/Failed
	MatrixUserID   string              `json:"matrixUserID,omitempty"`
	RoomID         string              `json:"roomID,omitempty"`
	ContainerState string              `json:"containerState,omitempty"`
	LastHeartbeat  string              `json:"lastHeartbeat,omitempty"`
	Message        string              `json:"message,omitempty"`
	ExposedPorts   []ExposedPortStatus `json:"exposedPorts,omitempty"`
}

// ExposedPortStatus records a port that has been exposed via Higress.
type ExposedPortStatus struct {
	Port   int    `json:"port"`
	Domain string `json:"domain"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

type WorkerList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Worker `json:"items"`
}

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Team represents a group of workers led by a Team Leader.
type Team struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`
	Spec              TeamSpec   `json:"spec"`
	Status            TeamStatus `json:"status,omitempty"`
}

type TeamSpec struct {
	Description  string           `json:"description,omitempty"`
	Admin        *TeamAdminSpec   `json:"admin,omitempty"`
	Leader       LeaderSpec       `json:"leader"`
	Workers      []TeamWorkerSpec `json:"workers"`
	PeerMentions *bool            `json:"peerMentions,omitempty"` // default true
	ChannelPolicy   *ChannelPolicySpec  `json:"channelPolicy,omitempty"`  // team-wide overrides
}

type TeamAdminSpec struct {
	Name         string `json:"name"`
	MatrixUserID string `json:"matrixUserId,omitempty"`
}

type LeaderSpec struct {
	Name       string          `json:"name"`
	Model      string          `json:"model,omitempty"`
	Identity   string          `json:"identity,omitempty"`
	Soul       string          `json:"soul,omitempty"`
	Agents     string          `json:"agents,omitempty"`
	Package    string          `json:"package,omitempty"`
	ChannelPolicy *ChannelPolicySpec `json:"channelPolicy,omitempty"`
}

type TeamWorkerSpec struct {
	Name       string          `json:"name"`
	Model      string          `json:"model,omitempty"`
	Runtime    string          `json:"runtime,omitempty"`
	Image      string          `json:"image,omitempty"`
	Identity   string          `json:"identity,omitempty"`
	Soul       string          `json:"soul,omitempty"`
	Agents     string          `json:"agents,omitempty"`
	Skills     []string        `json:"skills,omitempty"`
	McpServers []string        `json:"mcpServers,omitempty"`
	Package    string          `json:"package,omitempty"`
	Expose     []ExposePort    `json:"expose,omitempty"`
	ChannelPolicy *ChannelPolicySpec `json:"channelPolicy,omitempty"`
}

type TeamStatus struct {
	Phase        string `json:"phase,omitempty"` // Pending/Active/Degraded
	TeamRoomID   string `json:"teamRoomID,omitempty"`
	LeaderReady  bool   `json:"leaderReady,omitempty"`
	ReadyWorkers int    `json:"readyWorkers,omitempty"`
	TotalWorkers int    `json:"totalWorkers,omitempty"`
	Message      string `json:"message,omitempty"`
	WorkerExposedPorts map[string][]ExposedPortStatus `json:"workerExposedPorts,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

type TeamList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Team `json:"items"`
}

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Human represents a real human user with configurable access permissions.
type Human struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`
	Spec              HumanSpec   `json:"spec"`
	Status            HumanStatus `json:"status,omitempty"`
}

type HumanSpec struct {
	DisplayName       string   `json:"displayName"`
	Email             string   `json:"email,omitempty"`
	PermissionLevel   int      `json:"permissionLevel"` // 1=Admin, 2=Team, 3=Worker
	AccessibleTeams   []string `json:"accessibleTeams,omitempty"`
	AccessibleWorkers []string `json:"accessibleWorkers,omitempty"`
	Note              string   `json:"note,omitempty"`
}

type HumanStatus struct {
	Phase           string   `json:"phase,omitempty"` // Pending/Active/Failed
	MatrixUserID    string   `json:"matrixUserID,omitempty"`
	InitialPassword string   `json:"initialPassword,omitempty"` // Set on creation, shown once
	Rooms           []string `json:"rooms,omitempty"`
	EmailSent       bool     `json:"emailSent,omitempty"`
	Message      string   `json:"message,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

type HumanList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Human `json:"items"`
}
