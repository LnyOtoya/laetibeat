package main

import (
	"crypto/subtle"
	"encoding/json"
	"log"
	"net/http"
	"path"
	"strings"
	"time"
)

const maxRequestBodyBytes = 4 << 20

// 上游有风险或 App 不需要的路由，在进入 go-music-api 之前直接拒绝。
var blockedExactPaths = map[string]struct{}{
	// 任意 URL 抓取，SSRF。
	"/api/v1/music/cover":   {},
	"/music/download_cover": {},
	// 返回明文 Cookie。
	"/api/v1/system/cookies": {},
	"/music/cookies":         {},
}

func withSecurity(next http.Handler, token string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if isBlockedPath(r.URL.Path) {
			http.NotFound(w, r)
			return
		}
		if token != "" && !authorized(r, token) {
			writeUnauthorized(w)
			return
		}

		r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)
		w.Header().Set("X-Content-Type-Options", "nosniff")
		next.ServeHTTP(noCORSWriter{ResponseWriter: w}, r)
	})
}

func authorized(r *http.Request, token string) bool {
	const prefix = "Bearer "
	value := r.Header.Get("Authorization")
	if !strings.HasPrefix(value, prefix) {
		return false
	}
	got := strings.TrimSpace(strings.TrimPrefix(value, prefix))
	return subtle.ConstantTimeCompare([]byte(got), []byte(token)) == 1
}

func isBlockedPath(rawPath string) bool {
	cleaned := path.Clean("/" + rawPath)
	if _, ok := blockedExactPaths[cleaned]; ok {
		return true
	}
	if cleaned == "/swagger" || strings.HasPrefix(cleaned, "/swagger/") {
		return true
	}
	// 整组兼容路由 App 不使用；封掉可减少攻击面。
	if cleaned == "/music" || strings.HasPrefix(cleaned, "/music/") {
		return true
	}
	return false
}

func writeUnauthorized(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"code": http.StatusUnauthorized,
		"msg":  "unauthorized",
	})
}

// 上游 Gin 会设置通配 CORS；原生 App 不需要，直接移除。
type noCORSWriter struct {
	http.ResponseWriter
}

func (w noCORSWriter) WriteHeader(statusCode int) {
	h := w.Header()
	for _, key := range []string{
		"Access-Control-Allow-Origin",
		"Access-Control-Allow-Methods",
		"Access-Control-Allow-Headers",
		"Access-Control-Allow-Credentials",
		"Access-Control-Expose-Headers",
	} {
		h.Del(key)
	}
	w.ResponseWriter.WriteHeader(statusCode)
}

func (w noCORSWriter) Flush() {
	if flusher, ok := w.ResponseWriter.(http.Flusher); ok {
		flusher.Flush()
	}
}

func withAccessLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(recorder, r)
		// 只记录 path，不记录 query / Cookie / 上游 URL。
		log.Printf(
			"%s %s %d %s",
			r.Method,
			r.URL.Path,
			recorder.status,
			time.Since(start).Round(time.Millisecond),
		)
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (r *statusRecorder) WriteHeader(statusCode int) {
	r.status = statusCode
	r.ResponseWriter.WriteHeader(statusCode)
}

func (r *statusRecorder) Flush() {
	if flusher, ok := r.ResponseWriter.(http.Flusher); ok {
		flusher.Flush()
	}
}
