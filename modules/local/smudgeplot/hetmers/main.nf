// TODO nf-core: If in doubt look at other nf-core/modules to see how we are doing things! :)
//               https://github.com/nf-core/modules/tree/master/modules/nf-core/
//               You can also ask for help via your pull request or on the #modules channel on the nf-core Slack workspace:
//               https://nf-co.re/join
// TODO nf-core: A module file SHOULD only define input and output files as command-line parameters.
//               All other parameters MUST be provided using the "task.ext" directive, see here:
//               https://www.nextflow.io/docs/latest/process.html#ext
//               where "task.ext" is a string.
//               Any parameters that need to be evaluated in the context of a particular sample
//               e.g. single-end/paired-end data MUST also be defined and evaluated appropriately.
// TODO nf-core: Software that can be piped together SHOULD be added to separate module files
//               unless there is a run-time, storage advantage in implementing in this way
//               e.g. it's ok to have a single module for bwa to output BAM instead of SAM:
//                 bwa mem | samtools view -B -T ref.fasta
// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process SMUDGEPLOT_HETMERS {
    tag "${meta.id}"
    label 'process_medium'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/67/67768ae2b68b74edaaa5132770984f2369e6e2d50595051953b87d339ecb915f/data'
        : 'community.wave.seqera.io/library/fastk_smudgeplot:31977b35fedfc753'}"

    input:
    // FastK table directory (contains FastK_Table files)
    tuple val(meta), path(fastk_table), path(fastk_supp_files)

    output:
    // Output .smu file with k-mer pairs
    tuple val(meta), path("*.smu"), emit: smu
    // TODO nf-core: List additional required output channels/values here
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: '-L 12'
    def prefix = task.ext.prefix ?: "${meta.id}"
    // Find the FastK_Table directory - it could be a directory or a file pattern
    def fastk_table_path = fastk_table.toString()
    """
    smudgeplot.py hetmers \\
        ${args} \\
        -t ${task.cpus} \\
        -o ${prefix} \\
        --verbose \\
        ${fastk_table_path}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        smudgeplot: \$(smudgeplot.py --version 2>&1 || echo "0.4.0")
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: '-L 12'
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_text.smu

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        smudgeplot: "0.4.0"
    END_VERSIONS
    """
}
