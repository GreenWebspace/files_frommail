app_name=files_frommail

project_dir=$(CURDIR)
build_dir=$(CURDIR)/build/artifacts
appstore_dir=$(build_dir)/appstore
source_dir=$(build_dir)/source
sign_dir=$(build_dir)/sign
package_name=$(app_name)
cert_dir=$(HOME)/.nextcloud/certificates
codecov_token_dir=$(HOME)/.nextcloud/codecov_token
github_account=nextcloud
branch=master
version+=0.3.0

all: appstore

release: appstore github-release github-upload

github-release:
	github-release release \
		--user $(github_account) \
		--repo $(app_name) \
		--target $(branch) \
		--tag v$(version) \
		--name "$(app_name) v$(version)"

github-upload:
	github-release upload \
		--user $(github_account) \
		--repo $(app_name) \
		--tag v$(version) \
		--name "$(app_name)-$(version).tar.gz" \
		--file $(build_dir)/$(app_name)-$(version).tar.gz

create-tag:
	git tag -s -a v$(version) -m "Tagging the $(version) release."
	git push origin v$(version)

clean:
	rm -rf $(build_dir)
	rm -rf node_modules

composer:
	composer install

test: SHELL:=/bin/bash
test: composer
	phpunit --coverage-clover=coverage.xml --configuration=tests/phpunit.xml tests
	@if [ -f $(codecov_token_dir)/$(app_name) ]; then \
		bash <(curl -s https://codecov.io/bash) -t @$(codecov_token_dir)/$(app_name) ; \
	fi


appstore: composer clean
	mkdir -p $(sign_dir)
	rsync -a \
	--exclude=/build \
	--exclude=/docs \
	--exclude=/translationfiles \
	--exclude=/.tx \
	--exclude=/tests \
	--exclude=/.git \
	--exclude=/.github \
	--exclude=/composer.json \
	--exclude=/composer.lock \
	--exclude=/l10n/l10n.pl \
	--exclude=/CONTRIBUTING.md \
	--exclude=/issue_template.md \
	--exclude=/README.md \
	--exclude=/.gitattributes \
	--exclude=.gitignore \
	--exclude=/.scrutinizer.yml \
	--exclude=/.travis.yml \
	--exclude=/Makefile \
	--exclude=/vendor/picocms/pico/index.php \
	$(project_dir)/ $(sign_dir)/$(app_name)
	tar -czf $(build_dir)/$(app_name)-$(version).tar.gz \
		-C $(sign_dir) $(app_name)
	@if [ -f $(cert_dir)/$(app_name).key ]; then \
		echo "Signing package…"; \
		openssl dgst -sha512 -sign $(cert_dir)/$(app_name).key $(build_dir)/$(app_name)-$(version).tar.gz | openssl base64; \
	fi
