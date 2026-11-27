package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/guohuiyuan/go-music-api/router"
	"github.com/guohuiyuan/go-music-api/service"
)

const (
	envAddr    = "LAETIBEAT_MUSICAPI_ADDR"
	envToken   = "LAETIBEAT_MUSICAPI_TOKEN"
	envDataDir = "LAETIBEAT_MUSICAPI_DATA_DIR"

	listenLinePrefix = "LAETIBEAT_MUSICAPI_LISTEN="
	defaultAddr      = "127.0.0.1:0"
)

func main() {
	if err := run(); err != nil {
		log.Fatalf("laetibeat musicapi host: %v", err)
	}
}

func run() error {
	if dir := strings.TrimSpace(os.Getenv(envDataDir)); dir != "" {
		if err := ensureDataDir(dir); err != nil {
			return err
		}
		if err := os.Chdir(dir); err != nil {
			return fmt.Errorf("chdir data dir: %w", err)
		}
	}

	// 上游使用 gin.Default()；关闭其访问日志，避免 query 中的敏感参数落盘。
	gin.SetMode(gin.ReleaseMode)
	gin.DefaultWriter = io.Discard
	service.CM.Load()

	engine := router.SetupRouter()
	mux := http.NewServeMux()
	mux.HandleFunc("/laetibeat/health", handleHealth)
	mux.Handle("/", engine)

	token := strings.TrimSpace(os.Getenv(envToken))
	handler := withAccessLog(withSecurity(mux, token))

	addr := strings.TrimSpace(os.Getenv(envAddr))
	if addr == "" {
		addr = defaultAddr
	}
	if token == "" && !isLoopbackAddr(addr) {
		return fmt.Errorf(
			"refusing to listen on %s without %s",
			addr,
			envToken,
		)
	}
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", addr, err)
	}
	// Dart 侧读取这一行拿到实际端口；HTTP 只绑定在指定地址上。
	fmt.Printf("%s%s\n", listenLinePrefix, ln.Addr().String())

	srv := &http.Server{
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	ctx, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer stop()

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(
			context.Background(),
			5*time.Second,
		)
		defer cancel()
		_ = srv.Shutdown(shutdownCtx)
	}()

	if err := srv.Serve(ln); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return fmt.Errorf("serve: %w", err)
	}
	return nil
}

func ensureDataDir(dir string) error {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return fmt.Errorf("create data dir: %w", err)
	}
	info, err := os.Stat(dir)
	if err != nil {
		return fmt.Errorf("stat data dir: %w", err)
	}
	if !info.IsDir() {
		return fmt.Errorf("data dir is not a directory: %s", dir)
	}
	return nil
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = io.WriteString(w, `{"status":"ok"}`)
}

func isLoopbackAddr(addr string) bool {
	host, _, err := net.SplitHostPort(addr)
	if err != nil || host == "" {
		return false
	}
	if strings.EqualFold(host, "localhost") {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}
