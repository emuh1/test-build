#!/bin/bash -e

exitError()
{
    printf "ERROR: $*\n"
    exit 1
}

DOCKER_DEPS="${PWD}"
C_DEBIAN="${DOCKER_DEPS}/CHIP-debian"
C_TOOLS="${DOCKER_DEPS}/CHIP-tools"
C_SERVER="${DOCKER_DEPS}/CHIP-server"
C_POSTCHROOT="${DOCKER_DEPS}/CHIP-postchroot"
C_IAAS_DEPS="${DOCKER_DEPS}/iaas-chip-dependencies.tar.gz"
C_IAAS_BASE_ROOTFS="${DOCKER_DEPS}/postchroot-rootfs.tar.gz"
C_IAAS_PROV="${C_DEBIAN}/provision-node"
FS_BUILD_DIR="${PWD}/build"
OUTPUT_DIR="${FS_BUILD_DIR}/output"

#####################################################################################
# Check that everything is available
#####################################################################################
MISSING_DEPENDENCY_STRING=""
[[ ! -e "${C_DEBIAN}" ]] &&     MISSING_DEPENDENCY_STRING="${MISSING_DEPENDENCY_STRING}git clone https://github.com/snuk-io/CHIP-debian.git\n"
[[ ! -e "${C_TOOLS}" ]] &&      MISSING_DEPENDENCY_STRING="${MISSING_DEPENDENCY_STRING}git clone https://github.com/snuk-io/CHIP-tools.git\n"
[[ ! -e "${C_SERVER}" ]] &&     MISSING_DEPENDENCY_STRING="${MISSING_DEPENDENCY_STRING}git clone https://github.com/snuk-io/CHIP-server.git\n"
[[ ! -e "${C_POSTCHROOT}" ]] && MISSING_DEPENDENCY_STRING="${MISSING_DEPENDENCY_STRING}git clone https://github.com/snuk-io/CHIP-postchroot.git\n"
[[ ! -e "${C_IAAS_PROV}" ]] &&  MISSING_DEPENDENCY_STRING="${MISSING_DEPENDENCY_STRING}git clone https://github.com/snuk-io/provision-node\n"
[[ ! -e "${C_IAAS_DEPS}" ]] &&  MISSING_DEPENDENCY_STRING="${MISSING_DEPENDENCY_STRING}wget https://s3.eu-central-1.amazonaws.com/iaas-chip-dependencies/iaas-chip-dependencies.tar.gz\n"
[[ ! -e "${C_IAAS_BASE_ROOTFS}" ]] &&  MISSING_DEPENDENCY_STRING="${MISSING_DEPENDENCY_STRING}wget https://s3.eu-central-1.amazonaws.com/iaas-chip-dependencies/postchroot-rootfs.tar.gz\n"

ln -s "${C_DEBIAN}/vagrant" .
ln -s "${C_IAAS_PROV}" "${C_DEBIAN}/vagrant/iaas-chip-node"
if [[ -n "${MISSING_DEPENDENCY_STRING}" ]]
then
    exitError "Missing dependencies can be solved by:\nmkdir -p docker/deps\npushd docker/deps\n${MISSING_DEPENDENCY_STRING}popd"
fi

# Create the needed directories
sudo rm -rf "${FS_BUILD_DIR}"
mkdir -p "${FS_BUILD_DIR}" "${OUTPUT_DIR}"

# Install the needed scripts into the FS_BUILD_DIR
sudo tar -xf "${C_IAAS_DEPS}" -C "${FS_BUILD_DIR}"
sudo cp "${C_TOOLS}/common.sh" "${FS_BUILD_DIR}"
sudo cp "${C_TOOLS}/chip-create-nand-images.sh" "${FS_BUILD_DIR}"
sudo cp "${C_TOOLS}/chip-flash-nand-images.sh" "${FS_BUILD_DIR}"
sudo cp "${C_SERVER}/build.sh" "${FS_BUILD_DIR}/build-base-rootfs.sh"
sudo cp "${C_POSTCHROOT}/build.sh" "${FS_BUILD_DIR}/build-postchroot-rootfs.sh"

sudo cp "${PWD}/vagrant/build.sh" "${FS_BUILD_DIR}"
sudo cp "${PWD}/vagrant/build-base.sh" "${FS_BUILD_DIR}"
sudo cp "${PWD}/vagrant/build-extras.sh" "${FS_BUILD_DIR}"
sudo cp "${PWD}/vagrant/clean.sh" "${FS_BUILD_DIR}"
sudo ln -s "${C_IAAS_PROV}" "${FS_BUILD_DIR}/node"
sudo ln -s "${C_IAAS_BASE_ROOTFS}" "${FS_BUILD_DIR}/${C_IAAS_BASE_ROOTFS##*/}"

# Make binfmt support work for the change root into the sysroot
mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
update-binfmts --enable qemu-arm

# No the rootfs-builder directory should look the same as in vagrant
# Lets fire up the build script
pushd "${FS_BUILD_DIR}"
./build.sh
popd

mv "${OUTPUT_DIR}" "${FINAL_OUTPUT_DIR}"
