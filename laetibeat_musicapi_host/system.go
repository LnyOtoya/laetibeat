package main

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/guohuiyuan/go-music-api/service"
)

var supportedPlatforms = []string{"netease", "qq"}

type platformStatus struct {
	Source    string `json:"source"`
	HasCookie bool   `json:"has_cookie"`
}

func registerSystemRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /laetibeat/system/platforms", handlePlatformStatuses)
	mux.HandleFunc(
		"DELETE /laetibeat/system/platforms/{source}",
		handlePlatformLogout,
	)
}

func handlePlatformStatuses(w http.ResponseWriter, r *http.Request) {
	statuses := make([]platformStatus, 0, len(supportedPlatforms))
	for _, source := range supportedPlatforms {
		statuses = append(statuses, platformStatus{
			Source:    source,
			HasCookie: strings.TrimSpace(service.CM.Get(source)) != "",
		})
	}
	writeJSON(w, http.StatusOK, statuses)
}

func handlePlatformLogout(w http.ResponseWriter, r *http.Request) {
	source := strings.TrimSpace(r.PathValue("source"))
	if !isSupportedPlatform(source) {
		writeJSON(w, http.StatusBadRequest, map[string]any{
			"code": http.StatusBadRequest,
			"msg":  "unsupported platform",
		})
		return
	}

	service.CM.SetAll(map[string]string{source: ""})
	if err := service.CM.Save(); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{
			"code": http.StatusInternalServerError,
			"msg":  "failed to save cookies",
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
}

func isSupportedPlatform(source string) bool {
	for _, platform := range supportedPlatforms {
		if platform == source {
			return true
		}
	}
	return false
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
