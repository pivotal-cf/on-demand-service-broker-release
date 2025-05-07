// Copyright (C) 2016-Present Pivotal Software, Inc. All rights reserved.
// This program and the accompanying materials are made available under the terms of the under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

package cf

type ResourceNotFoundError struct {
	message string
}

func (e ResourceNotFoundError) Error() string {
	return e.message
}

func NewResourceNotFoundError(message string) error {
	return ResourceNotFoundError{message}
}

type UnauthorizedError struct {
	message string
}

func (e UnauthorizedError) Error() string {
	return e.message
}

func NewUnauthorizedError(message string) error {
	return UnauthorizedError{message}
}

type ForbiddenError struct {
	message string
}

func (e ForbiddenError) Error() string {
	return e.message
}

func NewForbiddenError(message string) error {
	return ForbiddenError{message}
}

type InvalidResponseError struct {
	message string
}

func (e InvalidResponseError) Error() string {
	return e.message
}

func NewInvalidResponseError(message string) error {
	return InvalidResponseError{message}
}
