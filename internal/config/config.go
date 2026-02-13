package config

import (
	"os"

	toml "github.com/pelletier/go-toml/v2"
)

type Config struct {
	General General `toml:"general" json:"general"`
	IPSets  []IPSet `toml:"ipset" json:"ipsets"`
	Lists   []List  `toml:"list" json:"lists"`
}

type General struct {
	ListsOutputDir string `toml:"lists_output_dir" json:"lists_output_dir"`
	UseKeeneticAPI bool   `toml:"use_keenetic_api" json:"use_keenetic_api"`
	UseKeeneticDNS bool   `toml:"use_keenetic_dns" json:"use_keenetic_dns"`
	FallbackDNS    string `toml:"fallback_dns" json:"fallback_dns"`
}

type IPSet struct {
	IPSetName           string   `toml:"ipset_name" json:"ipset_name"`
	Lists               []string `toml:"lists" json:"lists"`
	IPVersion           int      `toml:"ip_version" json:"ip_version"`
	FlushBeforeApplying bool     `toml:"flush_before_applying" json:"flush_before_applying"`
	Routing             Routing  `toml:"routing" json:"routing"`
}

type Routing struct {
	Interfaces  []string `toml:"interfaces" json:"interfaces"`
	KillSwitch  bool     `toml:"kill_switch" json:"kill_switch"`
	FWMark      int      `toml:"fwmark" json:"fwmark"`
	Table       int      `toml:"table" json:"table"`
	Priority    int      `toml:"priority" json:"priority"`
	OverrideDNS string   `toml:"override_dns,omitempty" json:"override_dns,omitempty"`
}

type List struct {
	ListName string   `toml:"list_name" json:"list_name"`
	URL      string   `toml:"url,omitempty" json:"url,omitempty"`
	File     string   `toml:"file,omitempty" json:"file,omitempty"`
	Hosts    []string `toml:"hosts,omitempty" json:"hosts,omitempty"`
}

// Load reads a TOML config file and returns a Config struct.
func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg Config
	if err := toml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

// Save writes a Config struct to a TOML file.
func Save(path string, cfg *Config) error {
	data, err := toml.Marshal(cfg)
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

// LoadRaw reads the raw TOML content as a string.
func LoadRaw(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

// SaveRaw writes raw TOML content to the config file.
// It validates the TOML before saving.
func SaveRaw(path string, content string) error {
	// Validate TOML by trying to parse it
	var cfg Config
	if err := toml.Unmarshal([]byte(content), &cfg); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content), 0644)
}
