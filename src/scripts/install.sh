Install_Cosign() {
    bootstrap_version='v1.0.0'
    expected_bootstrap_version_digest='e36a05ab402bfee5463ad4752d8dc2941204c7b01a9a9931f921e91d94ba2484'
    curl -L https://storage.googleapis.com/cosign-releases/v1.0.0/cosign-linux-amd64 -o cosign
    shaBootstrap=$(shasum -a 256 cosign | cut -d' ' -f1);
    if [[ $shaBootstrap != ${expected_bootstrap_version_digest} ]]; then exit 1; fi
    chmod +x cosign

    # If the bootstrap and specified `cosign` releases are the same, we're done.
    if [[ ${{ inputs.cosign-release }} == ${bootstrap_version} ]]; then exit 0; fi

    semver='^v([0-9]+\.){0,2}(\*|[0-9]+)$'
    if [[ ${{ inputs.cosign-release }} =~ $semver ]]; then
        echo "INFO: Custom Cosign Version ${{ inputs.cosign-release }}"
    else
        echo "ERROR: Unable to validate cosign version: '${{ inputs.cosign-release }}'"
        exit 1
    fi

    # Download custom cosign
    if [[ ${{ inputs.cosign-release }} == 'v0.6.0' ]]; then
        curl -L https://storage.googleapis.com/cosign-releases/v0.6.0/cosign_linux_amd64 -o cosign_${{ inputs.cosign-release }}
    else
        curl -L https://storage.googleapis.com/cosign-releases/${{ inputs.cosign-release }}/cosign-linux-amd64 -o cosign_${{ inputs.cosign-release }}
    fi
    shaCustom=$(shasum -a 256 cosign_${{ inputs.cosign-release }} | cut -d' ' -f1);

    # same hash means it is the same release
    if [[ $shaCustom != $shaBootstrap ]];
    then
        if [[ ${{ inputs.cosign-release }} == 'v0.6.0' ]]; then
        # v0.6.0's linux release has a dependency on `libpcsclite1`
        sudo apt-get update -q
        sudo apt-get install -yq libpcsclite1
        curl -L https://github.com/sigstore/cosign/releases/download/v0.6.0/cosign_linux_amd64_0.6.0_linux_amd64.sig -o cosign-linux-amd64.sig
        else
        curl -LO https://github.com/sigstore/cosign/releases/download/${{ inputs.cosign-release }}/cosign-linux-amd64.sig
        fi
        if [[ ${{ inputs.cosign-release }} < 'v0.6.0' ]]; then
        curl -L https://raw.githubusercontent.com/sigstore/cosign/${{ inputs.cosign-release }}/.github/workflows/cosign.pub -o release-cosign.pub
        else
        curl -LO https://raw.githubusercontent.com/sigstore/cosign/${{ inputs.cosign-release }}/release/release-cosign.pub
        fi
        ./cosign verify-blob -key release-cosign.pub -signature cosign-linux-amd64.sig cosign_${{ inputs.cosign-release }}
        if [[ $? != 0 ]]; then exit 1; fi
        rm cosign
        mv cosign_${{ inputs.cosign-release }} cosign
        chmod +x cosign
    fi
    # Add to PATH
    chmod +x cosign && mkdir -p "$HOME"/.cosign && mv cosign "$HOME"/.cosign/
    echo "export PATH=${HOME}/.cosign:$PATH" >> "$BASH_ENV"
    source "$BASH_ENV"
}

# Will not run if sourced for bats-core tests.
# View src/tests for more information.
ORB_TEST_ENV="bats-core"
if [ "${0#*$ORB_TEST_ENV}" == "$0" ]; then
    Install_Cosign
fi
