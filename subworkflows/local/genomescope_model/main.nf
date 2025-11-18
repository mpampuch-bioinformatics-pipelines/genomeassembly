include { FASTK_FASTK        } from "../../../modules/nf-core/fastk/fastk/main"
include { SMUDGEPLOT_HETMERS } from '../../../modules/local/smudgeplot/hetmers/main'
include { SMUDGEPLOT_ALL     } from '../../../modules/local/smudgeplot/all/main'

workflow GENOMESCOPE_MODEL {
    take:
    reads // [meta, [reads]] 
    matreads // [meta, [matreads]] 
    patreads // [meta, [patreads]]
    trio_flag

    main:
    ch_versions = Channel.empty()
    patdb_ch = Channel.empty()
    patktab_ch = Channel.empty()

    //
    // MODULE: MERGE ALL READS IN ONE FILE
    //
    CAT_CAT_READS(reads)
    ch_versions = ch_versions.mix(CAT_CAT_READS.out.versions)

    //
    // LOGIC: KEEP THE CORRECT EXTENSION
    //
    CAT_CAT_READS.out.file_out
        .map { meta, reads_ch ->
            reads_ch.getName().endsWith('gz')
                ? [meta, reads_ch.getParent().toString() + '/' + reads_ch.getBaseName().toString() + '.fa.gz']
                : [meta, reads_ch.getParent().toString() + '/' + reads_ch.getBaseName().toString() + '.fa']
        }
        .set { reads_merged_ch }

    //
    // LOGIC: MAKE SURE MERGED READS HAVE THE PROPER EXTENTION
    //
    CAT_CAT_READS.out.file_out
        .join(reads_merged_ch)
        .map { meta, reads_old, reads_new -> reads_old.renameTo(reads_new) }

    //
    // MODULE: GENERATE KMER DATABASE
    //
    FASTK_FASTK(reads_merged_ch)
    ch_versions = ch_versions.mix(FASTK_FASTK.out.versions)

    //
    // MODULE: KEEP THE KMERS HISTOGRAM
    //
    FASTK_HISTEX(FASTK_FASTK.out.hist)
    ch_versions = ch_versions.mix(FASTK_HISTEX.out.versions)


    //
    // LOGIC: RUN TRIO WHEN TRIO DATA IS AVAILABLE
    //
    trio_flag
        .combine(patreads)
        .combine(matreads)
        .branch {
            trio: it[0] == "trio"
            non_trio: it[0] == "nontrio"
        }
        .set { trio_data }

    trio_data.trio
        .multiMap { trio_mode, pat_meta, pat_data, mat_meta, mat_data ->
            pat: tuple(pat_meta, pat_data)
            mat: tuple(mat_meta, mat_data)
        }
        .set { ch_trio_data }
    //
    // SUBWORKFLOW: RUN TRIO PROCESS WITH TRIO DATA
    //
    TRIO_PROCESS(
        FASTK_FASTK.out.ktab,
        ch_trio_data.mat,
        ch_trio_data.pat,
    )
    ch_versions = ch_versions.mix(TRIO_PROCESS.out.versions)

    //
    // MODULE: GENERATE GENOMESCOPE KMER COVERAGE MODEL
    //
    GENESCOPEFK(FASTK_HISTEX.out.hist)
    ch_versions = ch_versions.mix(GENESCOPEFK.out.versions)

    // View kmer channels and reads channels
    GENESCOPEFK.out.model.view { it -> "Genomescope model: " + it }
    FASTK_FASTK.out.hist.view { it -> "FastK histogram: " + it }
    FASTK_FASTK.out.ktab.view { it -> "FastK ktab: " + it }
    TRIO_PROCESS.out.phapktab.ifEmpty([]).view { it -> "TRIO_PROCESS phapktab: " + it }
    TRIO_PROCESS.out.mhapktab.ifEmpty([]).view { it -> "TRIO_PROCESS mhapktab: " + it }
    TRIO_PROCESS.out.matdb.ifEmpty([]).view { it -> "TRIO_PROCESS matdb: " + it }
    TRIO_PROCESS.out.patdb.ifEmpty([]).view { it -> "TRIO_PROCESS patdb: " + it }

    emit:
    model    = GENESCOPEFK.out.model
    hist     = FASTK_FASTK.out.hist
    ktab     = FASTK_FASTK.out.ktab
    phapktab = TRIO_PROCESS.out.phapktab.ifEmpty([])
    mhapktab = TRIO_PROCESS.out.mhapktab.ifEmpty([])
    matdb    = TRIO_PROCESS.out.matdb.ifEmpty([])
    patdb    = TRIO_PROCESS.out.patdb.ifEmpty([])
    versions = ch_versions
}
