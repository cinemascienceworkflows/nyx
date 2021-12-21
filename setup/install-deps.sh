#!/bin/bash -l

# adding comment

source ./pantheon/env.sh > /dev/null 2>&1

echo "PTN: Establishing Pantheon workflow directory:"
echo "     $PANTHEON_WORKFLOW_DIR"

PANTHEON_SOURCE_ROOT=$PWD

# these settings allow you to control what gets built ... 
BUILD_CLEAN=true
INSTALL_SPACK=true
USE_SPACK_CACHE=false
INSTALL_ASCENT=true
INSTALL_APP=false

# spack data
SPACK_COMPILER_MODULE=gcc/9.3.0
SPACK_COMMIT=285548588f533338cc5493a7ba492f107e714794
SPACK_NAME=e4s_pantheon
SPACK_CACHE_URL=https://cache.e4s.io/pantheon

# ASCENT
ASCENT_CONFIG_COMMIT=4d50b99846fff60944e72577fc13eab16cde61dc

# ---------------------------------------------------------------------------
#
# Build things, based on flags set above
#
# ---------------------------------------------------------------------------

START_TIME=$(date +"%r %Z")
echo ----------------------------------------------------------------------
echo "PTN: Start time: $START_TIME" 
echo ----------------------------------------------------------------------

# if a clean build, remove everything
if $BUILD_CLEAN; then
    echo ----------------------------------------------------------------------
    echo "PTN: clean build ..."
    echo ----------------------------------------------------------------------

    if [ -d $PANTHEON_WORKFLOW_DIR ]; then
        rm -rf $PANTHEON_WORKFLOW_DIR
    fi
    if [ ! -d $PANTHEON_PATH ]; then
        mkdir $PANTHEON_PATH
    fi
    if [ ! -d $PANTHEON_PROJECT_DIR ]; then
        mkdir $PANTHEON_PROJECT_DIR
    fi
    if [ ! -d $PANTHEON_WORKFLOW_ID_DIR ]; then
        mkdir $PANTHEON_WORKFLOW_ID_DIR
    fi
    mkdir $PANTHEON_WORKFLOW_DIR
    mkdir $PANTHEON_DATA_DIR
    mkdir $PANTHEON_RUN_DIR
fi

if $INSTALL_SPACK; then
    echo ----------------------------------------------------------------------
    echo "PTN: installing Spack ..."
    echo ----------------------------------------------------------------------

    pushd $PANTHEON_WORKFLOW_DIR > /dev/null 2>&1
    git clone https://github.com/spack/spack 
    pushd spack > /dev/null 2>&1
    git checkout $SPACK_COMMIT 
    popd > /dev/null 2>&1
    popd > /dev/null 2>&1
fi

if $INSTALL_ASCENT; then
    echo ----------------------------------------------------------------------
    echo "PTN: building ASCENT ..."
    echo ----------------------------------------------------------------------

    cp inputs/spack/spack_begin.yaml $PANTHEON_WORKFLOW_DIR
    pushd $PANTHEON_WORKFLOW_DIR > /dev/null 2>&1
    git clone git@github.com:Alpine-DAV/spack_configs.git
    pushd spack_configs > /dev/null 2>&1
    git checkout $ASCENT_CONFIG_COMMIT
    popd > /dev/null 2>&1
    # construct a single spack.yaml file from the files in the repository
    sed -i -e "s#^#  #" spack_configs/configs/olcf/summit_gcc_9.3.0_warpx/packages.yaml
    sed -i -e "/^[[:blank:]]*perl:/,+4 d" spack_configs/configs/olcf/summit_gcc_9.3.0_warpx/packages.yaml
    sed -i -e "s#^#  #" spack_configs/configs/olcf/summit_gcc_9.3.0_warpx/compilers.yaml
    sed -i -e "/^[[:blank:]]*pkg-config:/,+4 d" spack_configs/configs/olcf/summit_gcc_9.3.0_warpx/packages.yaml
    cat spack_begin.yaml spack_configs/configs/olcf/summit_gcc_9.3.0_warpx/compilers.yaml spack_configs/configs/olcf/summit_gcc_9.3.0_warpx/packages.yaml > spack.yaml

    # activate spack and install Ascent
    # module load ${SPACK_COMPILER_MODULE}
    . spack/share/spack/setup-env.sh
    spack -e . concretize -f 2>&1 | tee concretize.log

    if $USE_SPACK_CACHE; then
        echo ----------------------------------------------------------------------
        echo "PTN: using Spack E4S cache ..."
        echo ----------------------------------------------------------------------

        # make sure correct mirror is used
        spack mirror remove $SPACK_NAME
        spack mirror add $SPACK_NAME $SPACK_CACHE_URL

        spack buildcache keys -it
        module load patchelf
    fi

    # install and generate module load commands for run step
    time spack -e . install
    spack -e . env loads

    popd
fi

# build the application and parts as needed
if $INSTALL_APP; then
    echo ----------------------------------------------------------------------
    echo "PTN: installing app ..."
    echo ----------------------------------------------------------------------

    source $PANTHEON_SOURCE_ROOT/setup/install-app.sh
fi

END_TIME=$(date +"%r %Z")
echo ----------------------------------------------------------------------
echo "PTN: statistics" 
echo "PTN: start: $START_TIME"
echo "PTN: end  : $END_TIME"
echo ----------------------------------------------------------------------

