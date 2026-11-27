package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestIsBlockedPath(t *testing.T) {
	blocked := []string{
		"/api/v1/music/cover",
		"/api/v1/music/cover/",
		"/music/download_cover",
		"/api/v1/system/cookies",
		"/music/cookies",
		"/swagger/index.html",
		"/music/search",
		"/music/",
		"/api/v1/music/cover/../cover",
	}
	for _, path := range blocked {
		if !isBlockedPath(path) {
			t.Fatalf("expected blocked: %s", path)
		}
	}

	allowed := []string{
		"/api/v1/music/search",
		"/api/v1/music/url",
		"/api/v1/music/lyric",
		"/api/v1/playlist/user",
		"/api/v1/ranking/hot",
		"/api/v1/system/qr_login/qq",
		"/laetibeat/health",
	}
	for _, path := range allowed {
		if isBlockedPath(path) {
			t.Fatalf("expected allowed: %s", path)
		}
	}
}

func TestWithSecurityAuth(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	handler := withSecurity(next, "secret")

	tests := []struct {
		name   string
		header string
		want   int
	}{
		{name: "missing", header: "", want: http.StatusUnauthorized},
		{name: "wrong", header: "Bearer nope", want: http.StatusUnauthorized},
		{name: "wrong scheme", header: "Basic secret", want: http.StatusUnauthorized},
		{name: "ok", header: "Bearer secret", want: http.StatusOK},
		{name: "extra whitespace", header: "Bearer   secret  ", want: http.StatusOK},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/api/v1/music/search", nil)
			if tc.header != "" {
				req.Header.Set("Authorization", tc.header)
			}
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)
			if rec.Code != tc.want {
				t.Fatalf("status = %d, want %d", rec.Code, tc.want)
			}
		})
	}
}

func TestWithSecurityNoTokenAllowsRequests(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	handler := withSecurity(next, "")

	req := httptest.NewRequest(http.MethodGet, "/api/v1/music/search", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
}

func TestWithSecurityBlocksRoutesEvenWithToken(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	handler := withSecurity(next, "secret")

	for _, path := range []string{
		"/api/v1/music/cover",
		"/music/download_cover",
		"/api/v1/system/cookies",
		"/music/cookies",
		"/swagger/index.html",
		"/music/search",
	} {
		req := httptest.NewRequest(http.MethodGet, path, nil)
		req.Header.Set("Authorization", "Bearer secret")
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		if rec.Code != http.StatusNotFound {
			t.Fatalf("%s status = %d, want 404", path, rec.Code)
		}
	}
}

func TestWithSecurityStripsCORS(t *testing.T) {
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Credentials", "true")
		w.WriteHeader(http.StatusOK)
	})
	handler := withSecurity(next, "")

	req := httptest.NewRequest(http.MethodGet, "/api/v1/music/search", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("Access-Control-Allow-Origin = %q, want empty", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Credentials"); got != "" {
		t.Fatalf("Access-Control-Allow-Credentials = %q, want empty", got)
	}
}

func TestEnsureDataDir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "nested", "data")
	if err := ensureDataDir(dir); err != nil {
		t.Fatalf("ensureDataDir: %v", err)
	}
	info, err := os.Stat(dir)
	if err != nil {
		t.Fatalf("stat: %v", err)
	}
	if !info.IsDir() {
		t.Fatalf("expected directory")
	}
}

func TestHealthHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/laetibeat/health", nil)
	rec := httptest.NewRecorder()
	handleHealth(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	if body := strings.TrimSpace(rec.Body.String()); body != `{"status":"ok"}` {
		t.Fatalf("body = %q", body)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Fatalf("Content-Type = %q", ct)
	}
}

func TestIsLoopbackAddr(t *testing.T) {
	tests := []struct {
		addr string
		want bool
	}{
		{addr: "127.0.0.1:0", want: true},
		{addr: "127.0.0.1:8080", want: true},
		{addr: "[::1]:8080", want: true},
		{addr: "localhost:8080", want: true},
		{addr: ":8080", want: false},
		{addr: "0.0.0.0:8080", want: false},
		{addr: "192.168.1.10:8080", want: false},
		{addr: "example.com:8080", want: false},
		{addr: "not-an-addr", want: false},
	}
	for _, tc := range tests {
		if got := isLoopbackAddr(tc.addr); got != tc.want {
			t.Fatalf("isLoopbackAddr(%q) = %v, want %v", tc.addr, got, tc.want)
		}
	}
}
