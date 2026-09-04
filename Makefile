.PHONY: build test run app clean

build:
	./Scripts/build-binary.sh

test:
	./Scripts/test.sh

run: app
	open ".build/Codex Pulse.app"

app:
	./Scripts/package-app.sh

clean:
	swift package clean
