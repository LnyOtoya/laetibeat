package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/guohuiyuan/go-music-api/service"
)

func TestPlatformStatusAndLogout(t *testing.T) {
	t.Chdir(t.TempDir())
	service.CM.SetAll(map[string]string{"netease": "", "qq": "a=b"})
	t.Cleanup(func() {
		service.CM.SetAll(map[string]string{"netease": "", "qq": ""})
	})

	mux := http.NewServeMux()
	registerSystemRoutes(mux)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/laetibeat/system/platforms", nil)
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var statuses []platformStatus
	if err := json.Unmarshal(rec.Body.Bytes(), &statuses); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if len(statuses) != 2 {
		t.Fatalf("len(statuses) = %d, want 2", len(statuses))
	}
	bySource := map[string]bool{}
	for _, status := range statuses {
		bySource[status.Source] = status.HasCookie
	}
	if !bySource["qq"] {
		t.Fatalf("qq should have cookie")
	}
	if bySource["netease"] {
		t.Fatalf("netease should not have cookie")
	}

	rec = httptest.NewRecorder()
	req = httptest.NewRequest(
		http.MethodDelete,
		"/laetibeat/system/platforms/qq",
		nil,
	)
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("logout status = %d, want 200", rec.Code)
	}
	if service.CM.Get("qq") != "" {
		t.Fatalf("qq cookie was not cleared")
	}
}

func TestPlatformLogoutRejectsUnknownSource(t *testing.T) {
	t.Chdir(t.TempDir())
	mux := http.NewServeMux()
	registerSystemRoutes(mux)

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(
		http.MethodDelete,
		"/laetibeat/system/platforms/unknown",
		nil,
	)
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}
