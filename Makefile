.PHONY: app run install test package release clean

test:
	./scripts/test.sh

app:
	./scripts/build.sh

run: app
	open build/Paneless.app

install:
	./scripts/install.sh

# make package VERSION=1.2.0
package:
	@test -n "$(VERSION)" || (echo "usage: make package VERSION=x.y.z" && exit 1)
	./scripts/package.sh $(VERSION)

# make release VERSION=1.2.0
release:
	@test -n "$(VERSION)" || (echo "usage: make release VERSION=x.y.z" && exit 1)
	./scripts/release.sh $(VERSION)

clean:
	rm -rf .build build
