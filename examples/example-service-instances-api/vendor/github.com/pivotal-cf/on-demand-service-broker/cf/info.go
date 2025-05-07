package cf

import (
	"fmt"
	"log"

	"github.com/blang/semver/v4"
)

func (c Client) GetAPIVersion(logger *log.Logger) (string, error) {
	var infoResponse infoResponse
	err := c.get(fmt.Sprintf("%s/v2/info", c.url), &infoResponse, logger)
	if err != nil {
		return "", err
	}
	return infoResponse.APIVersion, nil
}

func (c Client) CheckMinimumOSBAPIVersion(minimum string, logger *log.Logger) bool {
	min, err := semver.ParseTolerant(minimum)
	if err != nil {
		logger.Printf("error parsing specified OSBAPI version '%s' to semver: %v", minimum, err)
		return false
	}

	var infoResponse infoResponse
	if err := c.get(fmt.Sprintf("%s/v2/info", c.url), &infoResponse, logger); err != nil {
		logger.Printf("error requesting OSBAPI version: %v", err)
	}

	ver, err := semver.ParseTolerant(infoResponse.OSBAPIVersion)
	if err != nil {
		logger.Printf("error parsing discovered OSBAPI version '%s' to semver: %v", infoResponse.OSBAPIVersion, err)
		return false
	}

	return ver.GE(min)
}
