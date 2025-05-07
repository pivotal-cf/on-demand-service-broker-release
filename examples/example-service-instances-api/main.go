package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
)

var (
	state      *sync.Map
	statusCode uint32
)

func init() {
	state = &sync.Map{}
	atomic.StoreUint32(&statusCode, 200)
}

func key(queryParams url.Values) string {
	var keys []string
	for k := range queryParams {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var keyElements []string
	for _, k := range keys {
		values := queryParams[k]
		keyElements = append(keyElements, fmt.Sprintf("%s=%s", k, values[0]))
	}

	return strings.Join(keyElements, "&")
}

func setState(queryParams url.Values, val []byte) {
	state.Store(key(queryParams), val)
}

func getState(queryParams url.Values) []byte {
	errMessage, ok := state.Load("error")
	if ok {
		description := fmt.Sprintf(`{"description": "%s"}`, errMessage)
		return []byte(description)
	}
	val, ok := state.Load(key(queryParams))
	if !ok {
		return []byte("[]")
	}
	return val.([]byte)
}

func serviceInstancesHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("WWW-Authenticate", `Basic realm=""`)
	user, pass, _ := r.BasicAuth()
	if !checkAuth(user, pass) {
		http.Error(w, "Unauthorized.", http.StatusUnauthorized)
		return
	}

	switch r.Method {
	case "GET":
		listInstancesHandler(w, r)
	case "POST":
		setInstanceResponse(w, r)
	default:
		http.Error(w, "Page not found", http.StatusNotFound)

	}
}

func listInstancesHandler(w http.ResponseWriter, r *http.Request) {
	responseCode := int(atomic.LoadUint32(&statusCode))
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(responseCode)
	w.Write(getState(r.URL.Query()))
}

func setInstanceResponse(w http.ResponseWriter, r *http.Request) {
	forcedError, values := checkStatusCodeParam(r)
	if !forcedError {
		bodyContent, err := ioutil.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "POST body not readable", http.StatusInternalServerError)
		}
		setState(values, bodyContent)
	}
}

func checkStatusCodeParam(r *http.Request) (bool, url.Values) {
	values := r.URL.Query()
	e := values.Get("status-code")
	if code, err := strconv.Atoi(e); err == nil {
		if code == http.StatusOK {
			return removeForcedError(values)
		}

		return setForcedError(uint32(code)), values
	}
	return false, values
}

func setForcedError(errorStatusCode uint32) bool {
	atomic.StoreUint32(&statusCode, errorStatusCode)
	state.Store("error", "a forced error")
	return true
}

func removeForcedError(values url.Values) (bool, url.Values) {
	atomic.StoreUint32(&statusCode, http.StatusOK)
	state.Delete("error")
	values.Del("status-code")
	return false, values
}

func checkAuth(user, pass string) bool {
	correctUsername := os.Getenv("USERNAME")
	correctPassword := os.Getenv("PASSWORD")
	return user == correctUsername && pass == correctPassword
}

func main() {
	http.HandleFunc("/service_instances", serviceInstancesHandler)
	addr := fmt.Sprintf(":%s", os.Getenv("PORT"))
	log.Printf("Listening on %s\n", addr)
	http.ListenAndServe(addr, nil)
}
