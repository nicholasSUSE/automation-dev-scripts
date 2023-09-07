#!/bin/bash
# ARG SYSTEM_CHART_DEFAULT_BRANCH=dev-v2.7
# ARG CHART_DEFAULT_BRANCH=dev-v2.7
# ARG PARTNER_CHART_DEFAULT_BRANCH=main
# ARG RKE2_CHART_DEFAULT_BRANCH=main
VERSION="v2.5.17"
CATTLE_SYSTEM_CHART_DEFAULT_BRANCH="release-v2.5"
CATTLE_CHART_DEFAULT_BRANCH="release-v2.5"
CATTLE_PARTNER_CHART_DEFAULT_BRANCH="main"
CATTLE_RKE2_CHART_DEFAULT_BRANCH="main"
 
mkdir -p /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/system-library && \
mkdir -p /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/library && \
mkdir -p /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/helm3-library && \
mkdir -p /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/v2
 

# Command from 2.6 Up 
git clone -b $CATTLE_SYSTEM_CHART_DEFAULT_BRANCH --depth 1 https://github.com/rancher/system-charts /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/system-library && \
git clone -b $CATTLE_CHART_DEFAULT_BRANCH --depth 1 https://git.rancher.io/charts /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/v2/rancher-charts/4b40cac650031b74776e87c1a726b0484d0877c3ec137da0872547ff9b73a721/ && \
git clone -b $CATTLE_PARTNER_CHART_DEFAULT_BRANCH --depth 1 https://git.rancher.io/partner-charts /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/v2/rancher-partner-charts/8f17acdce9bffd6e05a58a3798840e408c4ea71783381ecd2e9af30baad65974 && \
git clone -b $CATTLE_RKE2_CHART_DEFAULT_BRANCH --depth 1 https://git.rancher.io/rke2-charts /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/v2/rancher-rke2-charts/675f1b63a0a83905972dcab2794479ed599a6f41b86cd6193d69472d0fa889c9 && \
git clone -b master --depth 1 https://github.com/rancher/charts /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/library && \
git clone -b master --depth 1 https://github.com/rancher/helm3-charts /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/helm3-library

# Command at 2.5
git clone -b $CATTLE_SYSTEM_CHART_DEFAULT_BRANCH --single-branch https://github.com/rancher/system-charts /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/system-library && \
git clone -b $CATTLE_CHART_DEFAULT_BRANCH --depth 1 https://git.rancher.io/charts /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/v2/rancher-charts/4b40cac650031b74776e87c1a726b0484d0877c3ec137da0872547ff9b73a721/ && \
git clone -b $CATTLE_PARTNER_CHART_DEFAULT_BRANCH --depth 1 https://git.rancher.io/partner-charts /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/v2/rancher-rke2-charts/675f1b63a0a83905972dcab2794479ed599a6f41b86cd6193d69472d0fa889c9 && \
git clone -b master --single-branch https://github.com/rancher/charts /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/library && \
git clone -b master --single-branch https://github.com/rancher/helm3-charts  /home/nick/RANCHER_DEV_ROOT_DIR/go/src/github.com/rancher/rancher-data/$VERSION/local-catalogs/helm3-library

