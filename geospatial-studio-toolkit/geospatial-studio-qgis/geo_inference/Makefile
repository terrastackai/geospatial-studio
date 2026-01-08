#/***************************************************************************
# GeoInference
#
# This plugin helps run inferences
#							 -------------------
#		begin				: 2025-06-11
#		git sha				: $Format:%H$
#		copyright			: (C) 2025 by IBM
#		email				: Fiona.Bundi@ibm.com
# ***************************************************************************/
#
#/***************************************************************************
# *																		 *
# *   This program is free software; you can redistribute it and/or modify  *
# *   it under the terms of the GNU General Public License as published by  *
# *   the Free Software Foundation; either version 2 of the License, or	 *
# *   (at your option) any later version.								   *
# *																		 *
# ***************************************************************************/

#################################################
# Edit the following to match your sources lists
#################################################


#Add iso code for any locales you want to support here (space separated)
# default is no locales
# LOCALES = af
LOCALES =

# If locales are enabled, set the name of the lrelease binary on your system. If
# you have trouble compiling the translations, you may have to specify the full path to
# lrelease
#LRELEASE = lrelease
#LRELEASE = lrelease-qt4


# translation
SOURCES = \
	__init__.py \
	geo_inference.py geo_inference_dialog.py

PLUGINNAME = geostudio

PY_FILES = \
	__init__.py \
	geo_inference.py geo_inference_dialog.py config.py \
	geo_inference_api.py geo_inference_wms_manager.py inference_request_builder.py geo_inference_spatial_Selector.py

UI_FILES = geo_inference_dialog_base.ui

EXTRAS = metadata.txt icon.png

EXTRA_DIRS = images/

COMPILED_RESOURCE_FILES = resources.py

PEP8EXCLUDE=pydev,resources.py,conf.py,third_party,ui

# QGISDIR points to the location where your plugin should be installed.
# This varies by platform, relative to your HOME directory:
#	* Linux:
#	  .local/share/QGIS/QGIS3/profiles/default/python/plugins/
#	* Mac OS X:
#	  Library/Application Support/QGIS/QGIS3/profiles/default/python/plugins
#	* Windows:
#	  AppData\Roaming\QGIS\QGIS3\profiles\default\python\plugins'

QGISDIR=Library/Application Support/QGIS/QGIS3/profiles/default/python/plugins

#################################################
# Normally you would not need to edit below here
#################################################

HELP = help/build/html

PLUGIN_UPLOAD = $(c)/plugin_upload.py

RESOURCE_SRC=$(shell grep '^ *<file' resources.qrc | sed 's@</file>@@g;s/.*>//g' | tr '\n' ' ')

PACKAGE_NAME = geostudio-qgis-plugin-$(VERSION)
VERSION := $(shell grep "version=" metadata.txt | cut -d'=' -f2)

.PHONY: default
default:
	@echo While you can use make to build and deploy your plugin, pb_tool
	@echo is a much better solution.
	@echo A Python script, pb_tool provides platform independent management of
	@echo your plugins and runs anywhere.
	@echo You can install pb_tool using: pip install pb_tool
	@echo See https://g-sherman.github.io/plugin_build_tool/ for info.

compile: $(COMPILED_RESOURCE_FILES)

%.py : %.qrc $(RESOURCES_SRC)
	pyrcc5 -o $*.py  $<

%.qm : %.ts
	$(LRELEASE) $<

# test: compile transcompile
# 	@echo
# 	@echo "----------------------"
# 	@echo "Regression Test Suite"
# 	@echo "----------------------"

# 	@# Preceding dash means that make will continue in case of errors
# 	@-export PYTHONPATH=`pwd`:$(PYTHONPATH); \
# 		export QGIS_DEBUG=0; \
# 		export QGIS_LOG_FILE=/dev/null; \
# 		nosetests -v --with-id --with-coverage --cover-package=. \
# 		3>&1 1>&2 2>&3 3>&- || true
# 	@echo "----------------------"
# 	@echo "If you get a 'no module named qgis.core error, try sourcing"
# 	@echo "the helper script we have provided first then run make test."
# 	@echo "e.g. source run-env-linux.sh <path to qgis install>; make test"
# 	@echo "----------------------"


# Install test dependencies
install-test:
	pip install -r requirements-test.txt

# Main test target - runs unit tests
test:
	@echo
	@echo "----------------------"
	@echo "Unit Test Suite"
	@echo "----------------------"
	@# Preceding dash means that make will continue in case of errors
	@-export PYTHONPATH=`pwd`/..:$(PYTHONPATH); \
		export QGIS_DEBUG=0; \
		export QGIS_LOG_FILE=/dev/null; \
		pytest tests/unit/ -v --tb=short \
		3>&1 1>&2 2>&3 3>&- || true
	@echo "----------------------"
	@echo "Unit tests completed. For GUI tests, run: make test-gui"
	@echo "If you get a 'no module named qgis.core error, try sourcing"
	@echo "the helper script we have provided first then run make test."
	@echo "e.g. source run-env-linux.sh <path to qgis install>; make test"
	@echo "----------------------"

# Test with coverage report
test-coverage:
	@echo
	@echo "----------------------"
	@echo "Unit Test Suite with Coverage"
	@echo "----------------------"
	@-export PYTHONPATH=`pwd`/..:$(PYTHONPATH); \
		export QGIS_DEBUG=0; \
		export QGIS_LOG_FILE=/dev/null; \
		pytest tests/unit/ --cov=. --cov-report=term-missing --cov-report=html -v --tb=short \
		|| true
	@echo "----------------------"
	@echo "Coverage report generated. Open htmlcov/index.html to view detailed report."
	@echo "To run tests without coverage, use: make test"
	@echo "----------------------"

deploy: compile doc
	@echo
	@echo "------------------------------------------"
	@echo "Deploying plugin to your .qgis2 directory."
	@echo "------------------------------------------"
	# The deploy  target only works on unix like operating system where
	# the Python plugin directory is located at:
	# $HOME/$(QGISDIR)
	mkdir -p "$(HOME)/$(QGISDIR)/$(PLUGINNAME)"
	cp -vf $(PY_FILES) "$(HOME)/$(QGISDIR)/$(PLUGINNAME)"
	cp -vf $(UI_FILES) "$(HOME)/$(QGISDIR)/$(PLUGINNAME)"
	cp -vf $(COMPILED_RESOURCE_FILES) "$(HOME)/$(QGISDIR)/$(PLUGINNAME)"
	cp -vf $(EXTRAS) "$(HOME)/$(QGISDIR)/$(PLUGINNAME)"
	# cp -vfr i18n "$(HOME)/$(QGISDIR)/$(PLUGINNAME)"
	# cp -vfr $(HELP) "$(HOME)/$(QGISDIR)/$(PLUGINNAME)/help"
	# Copy extra directories if any
	cp -vfr $(EXTRA_DIRS) "$(HOME)/$(QGISDIR)/$(PLUGINNAME)/"
	# (foreach EXTRA_DIR,(EXTRA_DIRS), cp -R (EXTRA_DIR) (HOME)/(QGISDIR)/(PLUGINNAME)/;)


# The dclean target removes compiled python files from plugin directory
# also deletes any .git entry
dclean:
	@echo
	@echo "-----------------------------------"
	@echo "Removing any compiled python files."
	@echo "-----------------------------------"
	find "$(HOME)/$(QGISDIR)/$(PLUGINNAME)" -iname "*.pyc" -delete
	find "$(HOME)/$(QGISDIR)/$(PLUGINNAME)" -iname ".git" -prune -exec rm -Rf {} +


derase:
	@echo
	@echo "-------------------------"
	@echo "Removing deployed plugin."
	@echo "-------------------------"
	rm -Rf $(HOME)/$(QGISDIR)/python/plugins/$(PLUGINNAME)

# The zip target deploys the plugin and creates a zip file with the deployed
#  content. You can then upload the zip file on http://plugins.qgis.org
# Gets version from metadata.txt
zip: dclean deploy
	@echo
	@echo "---------------------------"
	@echo "Creating plugin zip bundle."
	@echo "---------------------------"
	@mkdir -p ./package
	rm -f ./package/$(PLUGINNAME)-$(VERSION).zip
	cd "$(HOME)/Library/Application Support/QGIS/QGIS3/profiles/default/python/plugins" && zip -9r "$(CURDIR)/package/$(PLUGINNAME)-$(VERSION).zip" "$(PLUGINNAME)"
	@echo "Package created: ./package/$(PACKAGE_NAME).zip"

#  zip from current directory instead of QGIS plugins directory]

zip-local: dclean
	@echo
	@echo "---------------------------"
	@echo "Creating plugin zip bundle from local files."
	@echo "---------------------------"
	@mkdir -p ./package
	rm -f ./package/$(PACKAGE_NAME).zip
	# Create temporary directory with plugin name
	@mkdir -p ./temp/$(PLUGINNAME)
	# Copy ONLY plugin files (not everything)
	cp *.py ./temp/$(PLUGINNAME)/ 2>/dev/null || true
	cp metadata.txt ./temp/$(PLUGINNAME)/ 2>/dev/null || true
	cp -r resources ./temp/$(PLUGINNAME)/ 2>/dev/null || true
	cp -r ui ./temp/$(PLUGINNAME)/ 2>/dev/null || true
	cp -r icons ./temp/$(PLUGINNAME)/ 2>/dev/null || true
	cp -r help ./temp/$(PLUGINNAME)/ 2>/dev/null || true
	cp -r i18n ./temp/$(PLUGINNAME)/ 2>/dev/null || true
	cp *.qrc ./temp/$(PLUGINNAME)/ 2>/dev/null || true
	cp *.ui ./temp/$(PLUGINNAME)/ 2>/dev/null || true
	# Create zip from temp directory
	cd ./temp && zip -9r "../package/$(PACKAGE_NAME).zip" "$(PLUGINNAME)"
	# Clean up temp directory
	rm -rf ./temp
	@echo "Package created: ./package/$(PACKAGE_NAME).zip"

package: compile
	# Create a zip package of the plugin named $(PLUGINNAME).zip.
	# This requires use of git (your plugin development directory must be a
	# git repository).
	# To use, pass a valid commit or tag as follows:
	#   make package VERSION=Version_0.3.2
	@echo
	@echo "------------------------------------"
	@echo "Exporting plugin to zip package.	"
	@echo "------------------------------------"
	rm -f $(PLUGINNAME).zip
	git archive --prefix=$(PLUGINNAME)/ -o $(PLUGINNAME).zip $(VERSION)
	echo "Created package: $(PLUGINNAME).zip"

upload: zip
	@echo
	@echo "-------------------------------------"
	@echo "Uploading plugin to QGIS Plugin repo."
	@echo "-------------------------------------"
	$(PLUGIN_UPLOAD) $(PLUGINNAME).zip


clean:
	@echo
	@echo "------------------------------------"
	@echo "Removing uic and rcc generated files"
	@echo "------------------------------------"
	rm $(COMPILED_UI_FILES) $(COMPILED_RESOURCE_FILES)

doc:
	@echo
	@echo "------------------------------------"
	@echo "Building documentation using sphinx."
	@echo "------------------------------------"
	# cd help; make html

pylint:
	@echo
	@echo "-----------------"
	@echo "Pylint violations"
	@echo "-----------------"
	@pylint --reports=n --rcfile=pylintrc . || true
	@echo
	@echo "----------------------"
	@echo "If you get a 'no module named qgis.core' error, try sourcing"
	@echo "the helper script we have provided first then run make pylint."
	@echo "e.g. source run-env-linux.sh <path to qgis install>; make pylint"
	@echo "----------------------"


# Run pep8 style checking
#http://pypi.python.org/pypi/pep8
pep8:
	@echo
	@echo "-----------"
	@echo "PEP8 issues"
	@echo "-----------"
	@pep8 --repeat --ignore=E203,E121,E122,E123,E124,E125,E126,E127,E128 --exclude $(PEP8EXCLUDE) . || true
	@echo "-----------"
	@echo "Ignored in PEP8 check:"
	@echo $(PEP8EXCLUDE)
