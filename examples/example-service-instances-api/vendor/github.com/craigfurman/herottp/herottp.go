package herottp

import (
	"crypto/tls"
	"crypto/x509"
	"io"
	"net"
	"net/http"
	"net/url"
	"time"
)

type Client struct {
	*http.Client

	MaxRetries int
}

type Config struct {
	NoFollowRedirect                  bool
	DisableTLSCertificateVerification bool
	RootCAs                           *x509.CertPool
	Timeout                           time.Duration
	MaxRetries                        int
}

func New(config Config) *Client {
	c := &http.Client{Timeout: config.Timeout}

	if config.NoFollowRedirect {
		c.CheckRedirect = func(req *http.Request, via []*http.Request) error {
			return noFollowRedirect{}
		}
	}

	transport := &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		Dial: (&net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
		}).Dial,
		TLSHandshakeTimeout: 10 * time.Second,
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: config.DisableTLSCertificateVerification,
			RootCAs:            config.RootCAs,
		},
	}

	c.Transport = transport
	return &Client{
		Client:     c,
		MaxRetries: config.MaxRetries,
	}
}

func (c *Client) Do(req *http.Request) (resp *http.Response, err error) {
	attempts := 1 + c.MaxRetries

	for {
		switch attempts {
		case 0:
			return
		default:
			attempts -= 1

			resp, err = c.do(req)
			if err == nil {
				return
			}
		}
	}
}

func (c *Client) Get(url string) (resp *http.Response, err error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}

	return c.Do(req)
}

func (c *Client) Head(url string) (resp *http.Response, err error) {
	req, err := http.NewRequest("HEAD", url, nil)
	if err != nil {
		return nil, err
	}

	return c.Do(req)
}

func (c *Client) Post(url string, bodyType string, body io.Reader) (resp *http.Response, err error) {
	req, err := http.NewRequest("POST", url, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", bodyType)

	return c.Do(req)
}

func (c *Client) do(req *http.Request) (*http.Response, error) {
	resp, err := c.Client.Do(req)
	if e, isURLErr := err.(*url.Error); isURLErr {
		if _, ok := e.Err.(noFollowRedirect); ok {
			return resp, nil
		}
	}

	return resp, err
}

type noFollowRedirect struct{}

func (noFollowRedirect) Error() string {
	return "This error should not ever be returned!"
}
