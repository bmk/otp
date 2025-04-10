#
# %CopyrightBegin%
#
# SPDX-License-Identifier: Apache-2.0
# 
# Copyright Ericsson AB 1999-2025. All Rights Reserved.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# %CopyrightEnd%
#
# The Initial Developer of the Original Code is Ericsson Utvecklings AB.
# Portions created by Ericsson are Copyright 1999, Ericsson Utvecklings
# AB. All Rights Reserved.''
#
include $(ERL_TOP)/make/target.mk
include $(ERL_TOP)/make/$(TARGET)/otp.mk

SOCKET_MODULES = \
	observer_socket_test

KERNEL_MODULES = \
	shell_test_lib

MODULES =  \
	observer_SUITE \
	crashdump_viewer_SUITE \
	etop_SUITE \
	ttb_helper \
	ttb_SUITE \
	client \
	server \
	crashdump_helper \
	crashdump_helper_unicode \
	$(SOCKET_MODULES)

ERL_FILES= $(MODULES:%=%.erl) \
	$(KERNEL_MODULES:%=$(ERL_TOP)/lib/kernel/test/%.erl)

HRL_FILES= $(ERL_TOP)/lib/kernel/test/shell_test_lib.hrl

TARGET_FILES= $(MODULES:%=$(EBIN)/%.$(EMULATOR))
INSTALL_PROGS= $(TARGET_FILES)

EMAKEFILE=Emakefile
COVERFILE=observer.cover

# ----------------------------------------------------
# Release directory specification
# ----------------------------------------------------
RELSYSDIR = $(RELEASE_PATH)/observer_test

# ----------------------------------------------------
# FLAGS
# ----------------------------------------------------
ERL_MAKE_FLAGS +=
ERL_COMPILE_FLAGS += +warnings_as_errors +nowarn_export_all +nowarn_missing_spec_documented
ERL_COMPILE_FLAGS := $(filter-out +deterministic,$(ERL_COMPILE_FLAGS))

EBIN = .

TARGETS = $(MODULES:%=$(EBIN)/%.$(EMULATOR))
SOCKET_TARGETS = $(SOCKET_MODULES:%=$(EBIN)/%.$(EMULATOR))


# ----------------------------------------------------
# Targets
# ----------------------------------------------------
.PHONY: make_emakefile

make_emakefile:
	$(ERL_TOP)/make/make_emakefile $(ERL_COMPILE_FLAGS) -o$(EBIN) \
		$(MODULES) $(KERNEL_MODULES) > $(EMAKEFILE)

tests $(TYPES): make_emakefile
	erl $(ERL_MAKE_FLAGS) -make

clean:
	rm -f $(EMAKEFILE)
	rm -f $(TARGET_FILES)
	rm -f core

docs:

targets: $(TARGETS)
socket_targets: $(SOCKET_TARGETS)


# ----------------------------------------------------
# Special targets
# ----------------------------------------------------

# ----------------------------------------------------
# Release Target
# ---------------------------------------------------- 
include $(ERL_TOP)/make/otp_release_targets.mk

release_spec: opt

release_tests_spec: make_emakefile
	$(INSTALL_DIR) "$(RELSYSDIR)"
	$(INSTALL_DATA) $(ERL_FILES) $(HRL_FILES) "$(RELSYSDIR)"
	$(INSTALL_DATA) observer.spec $(EMAKEFILE) \
		$(COVERFILE) $(ERL_FILES) \
		"$(RELSYSDIR)"
	@tar cf - *_SUITE_data | (cd "$(RELSYSDIR)"; tar xf -)

release_docs_spec:


