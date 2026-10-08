# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

FROM python:3.13-slim@sha256:bf44cdfcb76cd3b41e879bc058fc37ec5872002ccfde7fcb765e218cde0cd79c
# requirements.txt is the hash-locked single source of truth, shared with CI
# and local virtual environments; see requirements.in.
COPY requirements.txt /tmp/requirements.txt
RUN python -m pip install --no-cache-dir --require-hashes --no-deps -r /tmp/requirements.txt \
    && python -m pip check \
    && rm /tmp/requirements.txt
