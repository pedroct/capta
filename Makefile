ifeq ($(origin DEVELOPER_DIR), undefined)
  export DEVELOPER_DIR := $(firstword $(wildcard /Applications/Xcode-beta.app/Contents/Developer /Applications/Xcode.app/Contents/Developer))
endif

FONTES := App Packages

# project.local.yml (assinatura) é opcional: o project.yml só o inclui se existir.
export CAPTA_LOCAL := $(if $(wildcard project.local.yml),true,false)

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: gerar format lint build test tokens entitlements cobertura verificar app

gerar:
	xcodegen generate

format:
	xcrun swift-format format --in-place --recursive $(FONTES)

lint:
	xcrun swift-format lint --strict --recursive $(FONTES)
	swiftlint lint --quiet

build: gerar
	xcodebuild -scheme Capta -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build | xcbeautify

test:
	cd Packages/CaptaNucleo && swift test

tokens:
	./ferramentas/conferir_tokens.sh

entitlements:
	./ferramentas/conferir_entitlements.sh

cobertura:
	./ferramentas/cobertura.sh

verificar: lint build cobertura tokens entitlements

app: gerar
	./ferramentas/empacotar.sh
