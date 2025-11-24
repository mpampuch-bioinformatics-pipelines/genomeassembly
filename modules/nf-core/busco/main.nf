process BUSCO {
    tag "${meta.id}"
    label 'process_medium'

    conda "bioconda::busco=5.4.3"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/41/4137d65ab5b90d2ae4fa9d3e0e8294ddccc287e53ca653bb3c63b8fdb03e882f/data'
        : 'community.wave.seqera.io/library/busco:6.0.0--a9a1426105f81165'}"

    input:
    tuple val(meta), path('tmp_input/*')
    val lineage
    // Required:    lineage to check against, "auto" enables --auto-lineage instead
    path busco_lineages_path
    // Recommended: path to busco lineages - downloads if not set
    path config_file

    output:
    tuple val(meta), path("*-busco.batch_summary.txt"), emit: batch_summary
    tuple val(meta), path("short_summary.*.txt"), emit: short_summaries_txt, optional: true
    tuple val(meta), path("short_summary.*.json"), emit: short_summaries_json, optional: true
    tuple val(meta), path("*-busco"), emit: busco_dir
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}-${lineage}"
    def busco_config = config_file ? "--config ${config_file}" : ''
    def busco_lineage = lineage.equals('auto') ? '--auto-lineage' : "--lineage_dataset ${lineage}"
    def busco_lineage_dir = busco_lineages_path ? "--offline --download_path ${busco_lineages_path}" : ''
    """
    # Nextflow changes the container --entrypoint to /bin/bash (container default entrypoint: /usr/local/env-execute)
    # Check for container variable initialisation script and source it.
    if [ -f "/usr/local/env-activate.sh" ]; then
        set +u  # Otherwise, errors out because of various unbound variables
        . "/usr/local/env-activate.sh"
        set -u
    fi

    set +u # Allow unbound variables
    # If the augustus config directory is not writable, then copy to writeable area
    if [ ! -w "\${AUGUSTUS_CONFIG_PATH}" ]; then
        # Create writable tmp directory for augustus
        AUG_CONF_DIR=\$( mktemp -d -p \$PWD )
        cp -r \$AUGUSTUS_CONFIG_PATH/* \$AUG_CONF_DIR
        export AUGUSTUS_CONFIG_PATH=\$AUG_CONF_DIR
        echo "New AUGUSTUS_CONFIG_PATH=\${AUGUSTUS_CONFIG_PATH}"
    else
        # If AUGUSTUS_CONFIG_PATH is writable or not set, create a directory anyway (does not copy files)
        AUG_CONF_DIR_DEFAULT=\$( mktemp -d -p \$PWD )
        export AUGUSTUS_CONFIG_PATH=\$AUG_CONF_DIR_DEFAULT
        echo "Default AUGUSTUS_CONFIG_PATH=\${AUGUSTUS_CONFIG_PATH}"
    fi
    set -u

    # Ensure the input is uncompressed
    INPUT_SEQS=input_seqs
    mkdir "\$INPUT_SEQS"
    cd "\$INPUT_SEQS"
    for FASTA in ../tmp_input/*; do
        if [ "\${FASTA##*.}" == 'gz' ]; then
            gzip -cdf "\$FASTA" > \$( basename "\$FASTA" .gz )
        else
            ln -s "\$FASTA" .
        fi
    done
    cd ..

    busco \\
        --cpu ${task.cpus} \\
        --in "\$INPUT_SEQS" \\
        --out ${prefix}-busco \\
        ${busco_lineage} \\
        ${busco_lineage_dir} \\
        ${busco_config} \\
        ${args}

    # clean up
    rm -rf "\$INPUT_SEQS"

    # Move files to avoid staging/publishing issues
    mv ${prefix}-busco/batch_summary.txt ${prefix}-busco.batch_summary.txt
    mv ${prefix}-busco/*/short_summary.*.{json,txt} . || echo "Short summaries were not available: No genes were found."

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$( busco --version 2>&1 | sed 's/^BUSCO //' )
    END_VERSIONS
    """
}
