ifeq ($(origin DEVELOPER_DIR), undefined)
  export DEVELOPER_DIR := $(firstword $(wildcard /Applications/Xcode.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer))
endif

# Só os diretórios que já existem (App entra com a tarefa do app).
FONTES := $(wildcard App Packages)

.PHONY: format lint test verificar

format:
	xcrun swift-format format --in-place --recursive $(FONTES)

lint:
	xcrun swift-format lint --strict --recursive $(FONTES)
	swiftlint lint --quiet

test:
	cd Packages/CaptaNucleo && swift test

verificar: lint test
