package shadowboxcore

import (
	"context"
	"sync"

	box "github.com/sagernet/sing-box"
	"github.com/sagernet/sing-box/include"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/json"
	"github.com/sagernet/sing/service/filemanager"
)

var runtimeState = struct {
	sync.Mutex
	instance *box.Box
	cancel   context.CancelFunc
}{}

func CheckConfig(configContent string) error {
	options, err := parseConfig(configContent, "", "", "")
	if err != nil {
		return err
	}
	instance, cancel, err := createInstance(options, "", "", "")
	if cancel != nil {
		cancel()
	}
	if instance != nil {
		_ = instance.Close()
	}
	return err
}

func Start(configContent string, workingPath string, tempPath string) error {
	runtimeState.Lock()
	defer runtimeState.Unlock()

	if runtimeState.instance != nil {
		_ = runtimeState.instance.Close()
		runtimeState.cancel()
		runtimeState.instance = nil
		runtimeState.cancel = nil
	}

	options, err := parseConfig(configContent, workingPath, workingPath, tempPath)
	if err != nil {
		return err
	}

	instance, cancel, err := createInstance(options, workingPath, workingPath, tempPath)
	if err != nil {
		if cancel != nil {
			cancel()
		}
		return err
	}

	if err = instance.Start(); err != nil {
		cancel()
		_ = instance.Close()
		return err
	}

	runtimeState.instance = instance
	runtimeState.cancel = cancel
	return nil
}

func Stop() error {
	runtimeState.Lock()
	defer runtimeState.Unlock()

	if runtimeState.instance == nil {
		return nil
	}

	err := runtimeState.instance.Close()
	runtimeState.cancel()
	runtimeState.instance = nil
	runtimeState.cancel = nil
	return err
}

func parseConfig(configContent string, basePath string, workingPath string, tempPath string) (option.Options, error) {
	ctx := makeContext(basePath, workingPath, tempPath)
	return json.UnmarshalExtendedContext[option.Options](ctx, []byte(configContent))
}

func createInstance(options option.Options, basePath string, workingPath string, tempPath string) (*box.Box, context.CancelFunc, error) {
	ctx, cancel := context.WithCancel(makeContext(basePath, workingPath, tempPath))
	instance, err := box.New(box.Options{
		Context: ctx,
		Options: options,
	})
	if err != nil {
		cancel()
		return nil, nil, err
	}
	return instance, cancel, nil
}

func makeContext(basePath string, workingPath string, tempPath string) context.Context {
	ctx := context.Background()
	ctx = box.Context(
		ctx,
		include.InboundRegistry(),
		include.OutboundRegistry(),
		include.EndpointRegistry(),
		include.DNSTransportRegistry(),
		include.ServiceRegistry(),
	)
	if workingPath != "" || tempPath != "" {
		ctx = filemanager.WithDefault(ctx, workingPath, tempPath, 0, 0)
	}
	return ctx
}
