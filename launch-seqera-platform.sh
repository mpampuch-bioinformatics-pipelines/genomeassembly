#!/usr/bin/env bash


################################################################################
# Tower CLI Workflow Launcher for IBEX
# 
# This script provides a flexible way to launch Nextflow workflows via 
# Seqera Platform (Tower) on KAUST IBEX HPC.
#
# Usage:
#   sbatch launch_tower_workflow.sh [options]
#
# Environment variables can be set to override defaults:
#   PIPELINE_NAME_OR_URL       - GitHub URL of the pipeline
#   PIPELINE_REVISION  - Git revision/branch/tag (default: master)
#   PARAMS_FILE        - Path to params JSON/YAML file
#   PROFILES           - Comma-separated list of profiles
#   WORKSPACE_ID       - Tower workspace ID
#   COMPUTE_ENV        - Tower compute environment name
#   WORK_DIR           - Launch work directory (overrides compute env default)
#   RUN_NAME           - Custom name for the workflow run
#   WAIT_FOR_COMPLETION - Set to "true" to wait for workflow to complete
################################################################################

################################################################################
# Pipeline to launch
################################################################################

PIPELINE_NAME_OR_URL="sangerToL_genome_assembly_local_fork"

################################################################################
# Setup
################################################################################

# Load modules
module load nextflow/25.04.2
module load singularity/3.9.7
module load tower-cli/0.15.0

# Configure Nextflow environment
export NXF_OPTS='-Xms3G -Xmx5G' # Allocate Java VM Heap memory range (for main process)
export NXF_SINGULARITY_CACHEDIR=/ibex/scratch/projects/c2303/NXF_SINGULARITY_CACHEDIR 
export NXF_APPTAINER_CACHEDIR=/ibex/scratch/projects/c2303/NXF_APPTAINER_CACHEDIR
export NXF_WORK=/ibex/scratch/projects/c2303/work

# Activate your environment for your job (if necessary)
# source env.sh 

# Activate Tower Credentials and Run the Tower Agent
source CONF/SEQERA-PLATFORM/run_tw_agent.sh

# Validate Tower credentials
if [ -z "${TOWER_ACCESS_TOKEN:-}" ]; then
    echo "Error: TOWER_ACCESS_TOKEN not set"
    echo "Please set it"
    exit 1
fi

################################################################################
# Common Configuration
################################################################################

COMPUTE_ENV="IBEX"
PROFILES="singularity,kaust"
TIMESTAMP=$(date -Iseconds | sed 's/-//g; s/://g; s/T/_/; s/+.*//')

NXF_OUTPUT_DIR="$(pwd)/OUTPUTS/$TIMESTAMP"
NXF_LOG_FILE="$NXF_OUTPUT_DIR/nextflow.log"

# Create output directory and copy useful files there for an easier time decipher the pipeline execution afterwards
mkdir -p "$NXF_OUTPUT_DIR"
cp "$0" "$NXF_OUTPUT_DIR/slurm_script.sbatch" # Copy the script to the output directory
echo "$(pwd)" > "$NXF_OUTPUT_DIR/projectDir.txt"

# Extract the launch directory from the compute environment configuration to be used in the post run script to copy the run output back to the project directory
NXF_LAUNCH_DIR=$(jq -r '.launchDir' CONF/SEQERA-PLATFORM/seqera-platform-IBEX-compute-env.json)
echo "NXF_LAUNCH_DIR: $NXF_LAUNCH_DIR"

################################################################################

# Launch Runs

# You can get the basic pipeline configuration using the following commands to help you modify pipeline configurations
# source ~/.secrets/seqera-platform.sh
# tw pipelines list
# tw pipelines export --name RNAseq

################################################################################

################################################################################
# Launch Run 1
################################################################################

# Launch with configuration 1
RUN_NAME="Galderia_sulphuria_Assembly_20kb_50x_Downsampled"
RUN_NAME_FULL="${RUN_NAME}_${TIMESTAMP}"
echo "RUN_NAME_FULL: $RUN_NAME_FULL"
RUN_LABELS="20kb_50x,time_${TIMESTAMP}"
echo "RUN_LABELS: $RUN_LABELS"
# Input file
INPUT_FILE="/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/INPUTS/Galdi_gt20_50x_samplesheet.yaml"
echo using input file: $INPUT_FILE
cp "$INPUT_FILE" "$NXF_OUTPUT_DIR" # Copy the input file to the output directory

NXF_OUTPUT_DIR_RUN_SPECIFIC="${NXF_OUTPUT_DIR}/${RUN_NAME}"
# Configs
CONFIG_FILE="nextflow.config"
CONFIG_FILE_RUN_SPECIFIC="$(basename $CONFIG_FILE .config).$RUN_NAME.config"
cp $CONFIG_FILE $CONFIG_FILE_RUN_SPECIFIC

# Modify your arguments here
cat << EOF >> "$CONFIG_FILE_RUN_SPECIFIC"
params.input = "$INPUT_FILE"
params.outdir = "$NXF_OUTPUT_DIR_RUN_SPECIFIC"

// process {
//   withName: '.*MULTIQC.*' {
//       ext.args = '--max-size 100g'
//   }
// }
EOF

RUN_POST_RUN_SCRIPT="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script.sh"
RUN_POST_RUN_SCRIPT_CALLBACK="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script_callback.sh"
echo "RUN_POST_RUN_SCRIPT_CALLBACK: $RUN_POST_RUN_SCRIPT_CALLBACK"

# Build the callback script that will execute the post-run script
"$(pwd)/UTILS/build_post_run_callback_script.sh" "$RUN_POST_RUN_SCRIPT" "$RUN_POST_RUN_SCRIPT_CALLBACK"

# Launch the run
echo "Launching run: $RUN_NAME_FULL"
tw launch "$PIPELINE_NAME_OR_URL" \
  --name "$RUN_NAME_FULL" \
  --labels "$RUN_LABELS" \
  --compute-env="$COMPUTE_ENV" \
  --profile "$PROFILES" \
  --config $CONFIG_FILE_RUN_SPECIFIC \
  --post-run "${RUN_POST_RUN_SCRIPT_CALLBACK}"

# Capture the workflow run ID of the latest run
WORKFLOW_RUN_ID=$(tw runs list --max 1 | awk 'NF' |  tail -n 1 | awk '{print $1}')

# Build the post run script to copy the run output back to the project directory
"$(pwd)/UTILS/build_post_run_script.sh" "$NXF_LAUNCH_DIR" "$WORKFLOW_RUN_ID" "$NXF_OUTPUT_DIR_RUN_SPECIFIC" "$RUN_POST_RUN_SCRIPT"


################################################################################
# Launch Run 2
################################################################################

# Launch with configuration 2
RUN_NAME="Galderia_sulphuria_Assembly_20kb_60x_Downsampled"
RUN_NAME_FULL="${RUN_NAME}_${TIMESTAMP}"
echo "RUN_NAME_FULL: $RUN_NAME_FULL"
RUN_LABELS="20kb_60x,time_${TIMESTAMP}"
echo "RUN_LABELS: $RUN_LABELS"
# Input file
INPUT_FILE="/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/INPUTS/Galdi_gt20_60x_samplesheet.yaml"
echo using input file: $INPUT_FILE
cp "$INPUT_FILE" "$NXF_OUTPUT_DIR" # Copy the input file to the output directory

NXF_OUTPUT_DIR_RUN_SPECIFIC="${NXF_OUTPUT_DIR}/${RUN_NAME}"
# Configs
CONFIG_FILE="nextflow.config"
CONFIG_FILE_RUN_SPECIFIC="$(basename $CONFIG_FILE .config).$RUN_NAME.config"
cp $CONFIG_FILE $CONFIG_FILE_RUN_SPECIFIC

# Modify your arguments here
cat << EOF >> "$CONFIG_FILE_RUN_SPECIFIC"
params.input = "$INPUT_FILE"
params.outdir = "$NXF_OUTPUT_DIR_RUN_SPECIFIC"

// process {
//   withName: '.*MULTIQC.*' {
//       ext.args = '--max-size 100g'
//   }
// }
EOF

RUN_POST_RUN_SCRIPT="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script.sh"
RUN_POST_RUN_SCRIPT_CALLBACK="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script_callback.sh"
echo "RUN_POST_RUN_SCRIPT_CALLBACK: $RUN_POST_RUN_SCRIPT_CALLBACK"

# Build the callback script that will execute the post-run script
"$(pwd)/UTILS/build_post_run_callback_script.sh" "$RUN_POST_RUN_SCRIPT" "$RUN_POST_RUN_SCRIPT_CALLBACK"

# Launch the run
echo "Launching run: $RUN_NAME_FULL"
tw launch "$PIPELINE_NAME_OR_URL" \
  --name "$RUN_NAME_FULL" \
  --labels "$RUN_LABELS" \
  --compute-env="$COMPUTE_ENV" \
  --profile "$PROFILES" \
  --config $CONFIG_FILE_RUN_SPECIFIC \
  --post-run "${RUN_POST_RUN_SCRIPT_CALLBACK}"

# Capture the workflow run ID of the latest run
WORKFLOW_RUN_ID=$(tw runs list --max 1 | awk 'NF' |  tail -n 1 | awk '{print $1}')

# Build the post run script to copy the run output back to the project directory
"$(pwd)/UTILS/build_post_run_script.sh" "$NXF_LAUNCH_DIR" "$WORKFLOW_RUN_ID" "$NXF_OUTPUT_DIR_RUN_SPECIFIC" "$RUN_POST_RUN_SCRIPT"


################################################################################
# Launch Run 3
################################################################################

# Launch with configuration 3
RUN_NAME="Galderia_sulphuria_Assembly_20kb_75x_Downsampled"
RUN_NAME_FULL="${RUN_NAME}_${TIMESTAMP}"
echo "RUN_NAME_FULL: $RUN_NAME_FULL"
RUN_LABELS="20kb_75x,time_${TIMESTAMP}"
echo "RUN_LABELS: $RUN_LABELS"
# Input file
INPUT_FILE="/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/INPUTS/Galdi_gt20_75x_samplesheet.yaml"
echo using input file: $INPUT_FILE
cp "$INPUT_FILE" "$NXF_OUTPUT_DIR" # Copy the input file to the output directory

NXF_OUTPUT_DIR_RUN_SPECIFIC="${NXF_OUTPUT_DIR}/${RUN_NAME}"
# Configs
CONFIG_FILE="nextflow.config"
CONFIG_FILE_RUN_SPECIFIC="$(basename $CONFIG_FILE .config).$RUN_NAME.config"
cp $CONFIG_FILE $CONFIG_FILE_RUN_SPECIFIC

# Modify your arguments here
cat << EOF >> "$CONFIG_FILE_RUN_SPECIFIC"
params.input = "$INPUT_FILE"
params.outdir = "$NXF_OUTPUT_DIR_RUN_SPECIFIC"

// process {
//   withName: '.*MULTIQC.*' {
//       ext.args = '--max-size 100g'
//   }
// }
EOF

RUN_POST_RUN_SCRIPT="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script.sh"
RUN_POST_RUN_SCRIPT_CALLBACK="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script_callback.sh"
echo "RUN_POST_RUN_SCRIPT_CALLBACK: $RUN_POST_RUN_SCRIPT_CALLBACK"

# Build the callback script that will execute the post-run script
"$(pwd)/UTILS/build_post_run_callback_script.sh" "$RUN_POST_RUN_SCRIPT" "$RUN_POST_RUN_SCRIPT_CALLBACK"

# Launch the run
echo "Launching run: $RUN_NAME_FULL"
tw launch "$PIPELINE_NAME_OR_URL" \
  --name "$RUN_NAME_FULL" \
  --labels "$RUN_LABELS" \
  --compute-env="$COMPUTE_ENV" \
  --profile "$PROFILES" \
  --config $CONFIG_FILE_RUN_SPECIFIC \
  --post-run "${RUN_POST_RUN_SCRIPT_CALLBACK}"

# Capture the workflow run ID of the latest run
WORKFLOW_RUN_ID=$(tw runs list --max 1 | awk 'NF' |  tail -n 1 | awk '{print $1}')

# Build the post run script to copy the run output back to the project directory
"$(pwd)/UTILS/build_post_run_script.sh" "$NXF_LAUNCH_DIR" "$WORKFLOW_RUN_ID" "$NXF_OUTPUT_DIR_RUN_SPECIFIC" "$RUN_POST_RUN_SCRIPT"


################################################################################
# Launch Run 4
################################################################################

# Launch with configuration 4
RUN_NAME="Galderia_sulphuria_Assembly_20kb_100x_Downsampled"
RUN_NAME_FULL="${RUN_NAME}_${TIMESTAMP}"
echo "RUN_NAME_FULL: $RUN_NAME_FULL"
RUN_LABELS="20kb_100x,time_${TIMESTAMP}"
echo "RUN_LABELS: $RUN_LABELS"
# Input file
INPUT_FILE="/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/INPUTS/Galdi_gt20_100x_samplesheet.yaml"
echo using input file: $INPUT_FILE
cp "$INPUT_FILE" "$NXF_OUTPUT_DIR" # Copy the input file to the output directory

NXF_OUTPUT_DIR_RUN_SPECIFIC="${NXF_OUTPUT_DIR}/${RUN_NAME}"
# Configs
CONFIG_FILE="nextflow.config"
CONFIG_FILE_RUN_SPECIFIC="$(basename $CONFIG_FILE .config).$RUN_NAME.config"
cp $CONFIG_FILE $CONFIG_FILE_RUN_SPECIFIC

# Modify your arguments here
cat << EOF >> "$CONFIG_FILE_RUN_SPECIFIC"
params.input = "$INPUT_FILE"
params.outdir = "$NXF_OUTPUT_DIR_RUN_SPECIFIC"

// process {
//   withName: '.*MULTIQC.*' {
//       ext.args = '--max-size 100g'
//   }
// }
EOF

RUN_POST_RUN_SCRIPT="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script.sh"
RUN_POST_RUN_SCRIPT_CALLBACK="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script_callback.sh"
echo "RUN_POST_RUN_SCRIPT_CALLBACK: $RUN_POST_RUN_SCRIPT_CALLBACK"

# Build the callback script that will execute the post-run script
"$(pwd)/UTILS/build_post_run_callback_script.sh" "$RUN_POST_RUN_SCRIPT" "$RUN_POST_RUN_SCRIPT_CALLBACK"

# Launch the run
echo "Launching run: $RUN_NAME_FULL"
tw launch "$PIPELINE_NAME_OR_URL" \
  --name "$RUN_NAME_FULL" \
  --labels "$RUN_LABELS" \
  --compute-env="$COMPUTE_ENV" \
  --profile "$PROFILES" \
  --config $CONFIG_FILE_RUN_SPECIFIC \
  --post-run "${RUN_POST_RUN_SCRIPT_CALLBACK}"

# Capture the workflow run ID of the latest run
WORKFLOW_RUN_ID=$(tw runs list --max 1 | awk 'NF' |  tail -n 1 | awk '{print $1}')

# Build the post run script to copy the run output back to the project directory
"$(pwd)/UTILS/build_post_run_script.sh" "$NXF_LAUNCH_DIR" "$WORKFLOW_RUN_ID" "$NXF_OUTPUT_DIR_RUN_SPECIFIC" "$RUN_POST_RUN_SCRIPT"


################################################################################
# Launch Run 5
################################################################################

# Launch with configuration 5
RUN_NAME="Galderia_sulphuria_Assembly_20kb_Downsampled"
RUN_NAME_FULL="${RUN_NAME}_${TIMESTAMP}"
echo "RUN_NAME_FULL: $RUN_NAME_FULL"
RUN_LABELS="20kb,time_${TIMESTAMP}"
echo "RUN_LABELS: $RUN_LABELS"
# Input file
INPUT_FILE="/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/INPUTS/Galdi_gt20_samplesheet.yaml"
echo using input file: $INPUT_FILE
cp "$INPUT_FILE" "$NXF_OUTPUT_DIR" # Copy the input file to the output directory

NXF_OUTPUT_DIR_RUN_SPECIFIC="${NXF_OUTPUT_DIR}/${RUN_NAME}"
# Configs
CONFIG_FILE="nextflow.config"
CONFIG_FILE_RUN_SPECIFIC="$(basename $CONFIG_FILE .config).$RUN_NAME.config"
cp $CONFIG_FILE $CONFIG_FILE_RUN_SPECIFIC

# Modify your arguments here
cat << EOF >> "$CONFIG_FILE_RUN_SPECIFIC"
params.input = "$INPUT_FILE"
params.outdir = "$NXF_OUTPUT_DIR_RUN_SPECIFIC"

// process {
//   withName: '.*MULTIQC.*' {
//       ext.args = '--max-size 100g'
//   }
// }
EOF

RUN_POST_RUN_SCRIPT="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script.sh"
RUN_POST_RUN_SCRIPT_CALLBACK="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script_callback.sh"
echo "RUN_POST_RUN_SCRIPT_CALLBACK: $RUN_POST_RUN_SCRIPT_CALLBACK"

# Build the callback script that will execute the post-run script
"$(pwd)/UTILS/build_post_run_callback_script.sh" "$RUN_POST_RUN_SCRIPT" "$RUN_POST_RUN_SCRIPT_CALLBACK"

# Launch the run
echo "Launching run: $RUN_NAME_FULL"
tw launch "$PIPELINE_NAME_OR_URL" \
  --name "$RUN_NAME_FULL" \
  --labels "$RUN_LABELS" \
  --compute-env="$COMPUTE_ENV" \
  --profile "$PROFILES" \
  --config $CONFIG_FILE_RUN_SPECIFIC \
  --post-run "${RUN_POST_RUN_SCRIPT_CALLBACK}"

# Capture the workflow run ID of the latest run
WORKFLOW_RUN_ID=$(tw runs list --max 1 | awk 'NF' |  tail -n 1 | awk '{print $1}')

# Build the post run script to copy the run output back to the project directory
"$(pwd)/UTILS/build_post_run_script.sh" "$NXF_LAUNCH_DIR" "$WORKFLOW_RUN_ID" "$NXF_OUTPUT_DIR_RUN_SPECIFIC" "$RUN_POST_RUN_SCRIPT"


################################################################################
# Launch Run 6
################################################################################

# Launch with configuration 6
RUN_NAME="Galderia_yellowstonsis_Assembly_10kb_50x_Downsampled"
RUN_NAME_FULL="${RUN_NAME}_${TIMESTAMP}"
echo "RUN_NAME_FULL: $RUN_NAME_FULL"
RUN_LABELS="yellowstonsis_10kb_50x,time_${TIMESTAMP}"
echo "RUN_LABELS: $RUN_LABELS"
# Input file
INPUT_FILE="/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/INPUTS/Galdi_yellowstonsis_gt10kb_50x_samplesheet.yaml"
echo using input file: $INPUT_FILE
cp "$INPUT_FILE" "$NXF_OUTPUT_DIR" # Copy the input file to the output directory

NXF_OUTPUT_DIR_RUN_SPECIFIC="${NXF_OUTPUT_DIR}/${RUN_NAME}"
# Configs
CONFIG_FILE="nextflow.config"
CONFIG_FILE_RUN_SPECIFIC="$(basename $CONFIG_FILE .config).$RUN_NAME.config"
cp $CONFIG_FILE $CONFIG_FILE_RUN_SPECIFIC

# Modify your arguments here
cat << EOF >> "$CONFIG_FILE_RUN_SPECIFIC"
params.input = "$INPUT_FILE"
params.outdir = "$NXF_OUTPUT_DIR_RUN_SPECIFIC"

// process {
//   withName: '.*MULTIQC.*' {
//       ext.args = '--max-size 100g'
//   }
// }
EOF

RUN_POST_RUN_SCRIPT="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script.sh"
RUN_POST_RUN_SCRIPT_CALLBACK="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script_callback.sh"
echo "RUN_POST_RUN_SCRIPT_CALLBACK: $RUN_POST_RUN_SCRIPT_CALLBACK"

# Build the callback script that will execute the post-run script
"$(pwd)/UTILS/build_post_run_callback_script.sh" "$RUN_POST_RUN_SCRIPT" "$RUN_POST_RUN_SCRIPT_CALLBACK"

# Launch the run
echo "Launching run: $RUN_NAME_FULL"
tw launch "$PIPELINE_NAME_OR_URL" \
  --name "$RUN_NAME_FULL" \
  --labels "$RUN_LABELS" \
  --compute-env="$COMPUTE_ENV" \
  --profile "$PROFILES" \
  --config $CONFIG_FILE_RUN_SPECIFIC \
  --post-run "${RUN_POST_RUN_SCRIPT_CALLBACK}"

# Capture the workflow run ID of the latest run
WORKFLOW_RUN_ID=$(tw runs list --max 1 | awk 'NF' |  tail -n 1 | awk '{print $1}')

# Build the post run script to copy the run output back to the project directory
"$(pwd)/UTILS/build_post_run_script.sh" "$NXF_LAUNCH_DIR" "$WORKFLOW_RUN_ID" "$NXF_OUTPUT_DIR_RUN_SPECIFIC" "$RUN_POST_RUN_SCRIPT"


################################################################################
# Launch Run 7
################################################################################

# Launch with configuration 7
RUN_NAME="Galderia_yellowstonsis_Assembly_10kb_60x_Downsampled"
RUN_NAME_FULL="${RUN_NAME}_${TIMESTAMP}"
echo "RUN_NAME_FULL: $RUN_NAME_FULL"
RUN_LABELS="yellowstonsis_10kb_60x,time_${TIMESTAMP}"
echo "RUN_LABELS: $RUN_LABELS"
# Input file
INPUT_FILE="/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/INPUTS/Galdi_yellowstonsis_gt10kb_60x_samplesheet.yaml"
echo using input file: $INPUT_FILE
cp "$INPUT_FILE" "$NXF_OUTPUT_DIR" # Copy the input file to the output directory

NXF_OUTPUT_DIR_RUN_SPECIFIC="${NXF_OUTPUT_DIR}/${RUN_NAME}"
# Configs
CONFIG_FILE="nextflow.config"
CONFIG_FILE_RUN_SPECIFIC="$(basename $CONFIG_FILE .config).$RUN_NAME.config"
cp $CONFIG_FILE $CONFIG_FILE_RUN_SPECIFIC

# Modify your arguments here
cat << EOF >> "$CONFIG_FILE_RUN_SPECIFIC"
params.input = "$INPUT_FILE"
params.outdir = "$NXF_OUTPUT_DIR_RUN_SPECIFIC"

// process {
//   withName: '.*MULTIQC.*' {
//       ext.args = '--max-size 100g'
//   }
// }
EOF

RUN_POST_RUN_SCRIPT="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script.sh"
RUN_POST_RUN_SCRIPT_CALLBACK="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script_callback.sh"
echo "RUN_POST_RUN_SCRIPT_CALLBACK: $RUN_POST_RUN_SCRIPT_CALLBACK"

# Build the callback script that will execute the post-run script
"$(pwd)/UTILS/build_post_run_callback_script.sh" "$RUN_POST_RUN_SCRIPT" "$RUN_POST_RUN_SCRIPT_CALLBACK"

# Launch the run
echo "Launching run: $RUN_NAME_FULL"
tw launch "$PIPELINE_NAME_OR_URL" \
  --name "$RUN_NAME_FULL" \
  --labels "$RUN_LABELS" \
  --compute-env="$COMPUTE_ENV" \
  --profile "$PROFILES" \
  --config $CONFIG_FILE_RUN_SPECIFIC \
  --post-run "${RUN_POST_RUN_SCRIPT_CALLBACK}"

# Capture the workflow run ID of the latest run
WORKFLOW_RUN_ID=$(tw runs list --max 1 | awk 'NF' |  tail -n 1 | awk '{print $1}')

# Build the post run script to copy the run output back to the project directory
"$(pwd)/UTILS/build_post_run_script.sh" "$NXF_LAUNCH_DIR" "$WORKFLOW_RUN_ID" "$NXF_OUTPUT_DIR_RUN_SPECIFIC" "$RUN_POST_RUN_SCRIPT"


################################################################################
# Launch Run 8
################################################################################

# Launch with configuration 8
RUN_NAME="Galderia_yellowstonsis_Assembly_10kb_75x_Downsampled"
RUN_NAME_FULL="${RUN_NAME}_${TIMESTAMP}"
echo "RUN_NAME_FULL: $RUN_NAME_FULL"
RUN_LABELS="yellowstonsis_10kb_75x,time_${TIMESTAMP}"
echo "RUN_LABELS: $RUN_LABELS"
# Input file
INPUT_FILE="/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/INPUTS/Galdi_yellowstonsis_gt10kb_75x_samplesheet.yaml"
echo using input file: $INPUT_FILE
cp "$INPUT_FILE" "$NXF_OUTPUT_DIR" # Copy the input file to the output directory

NXF_OUTPUT_DIR_RUN_SPECIFIC="${NXF_OUTPUT_DIR}/${RUN_NAME}"
# Configs
CONFIG_FILE="nextflow.config"
CONFIG_FILE_RUN_SPECIFIC="$(basename $CONFIG_FILE .config).$RUN_NAME.config"
cp $CONFIG_FILE $CONFIG_FILE_RUN_SPECIFIC

# Modify your arguments here
cat << EOF >> "$CONFIG_FILE_RUN_SPECIFIC"
params.input = "$INPUT_FILE"
params.outdir = "$NXF_OUTPUT_DIR_RUN_SPECIFIC"

// process {
//   withName: '.*MULTIQC.*' {
//       ext.args = '--max-size 100g'
//   }
// }
EOF

RUN_POST_RUN_SCRIPT="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script.sh"
RUN_POST_RUN_SCRIPT_CALLBACK="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script_callback.sh"
echo "RUN_POST_RUN_SCRIPT_CALLBACK: $RUN_POST_RUN_SCRIPT_CALLBACK"

# Build the callback script that will execute the post-run script
"$(pwd)/UTILS/build_post_run_callback_script.sh" "$RUN_POST_RUN_SCRIPT" "$RUN_POST_RUN_SCRIPT_CALLBACK"

# Launch the run
echo "Launching run: $RUN_NAME_FULL"
tw launch "$PIPELINE_NAME_OR_URL" \
  --name "$RUN_NAME_FULL" \
  --labels "$RUN_LABELS" \
  --compute-env="$COMPUTE_ENV" \
  --profile "$PROFILES" \
  --config $CONFIG_FILE_RUN_SPECIFIC \
  --post-run "${RUN_POST_RUN_SCRIPT_CALLBACK}"

# Capture the workflow run ID of the latest run
WORKFLOW_RUN_ID=$(tw runs list --max 1 | awk 'NF' |  tail -n 1 | awk '{print $1}')

# Build the post run script to copy the run output back to the project directory
"$(pwd)/UTILS/build_post_run_script.sh" "$NXF_LAUNCH_DIR" "$WORKFLOW_RUN_ID" "$NXF_OUTPUT_DIR_RUN_SPECIFIC" "$RUN_POST_RUN_SCRIPT"


################################################################################
# Launch Run 9
################################################################################

# Launch with configuration 9
RUN_NAME="Galderia_yellowstonsis_Assembly_10kb_100x_Downsampled"
RUN_NAME_FULL="${RUN_NAME}_${TIMESTAMP}"
echo "RUN_NAME_FULL: $RUN_NAME_FULL"
RUN_LABELS="yellowstonsis_10kb_100x,time_${TIMESTAMP}"
echo "RUN_LABELS: $RUN_LABELS"
# Input file
INPUT_FILE="/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/INPUTS/Galdi_yellowstonsis_gt10kb_100x_samplesheet.yaml"
echo using input file: $INPUT_FILE
cp "$INPUT_FILE" "$NXF_OUTPUT_DIR" # Copy the input file to the output directory

NXF_OUTPUT_DIR_RUN_SPECIFIC="${NXF_OUTPUT_DIR}/${RUN_NAME}"
# Configs
CONFIG_FILE="nextflow.config"
CONFIG_FILE_RUN_SPECIFIC="$(basename $CONFIG_FILE .config).$RUN_NAME.config"
cp $CONFIG_FILE $CONFIG_FILE_RUN_SPECIFIC

# Modify your arguments here
cat << EOF >> "$CONFIG_FILE_RUN_SPECIFIC"
params.input = "$INPUT_FILE"
params.outdir = "$NXF_OUTPUT_DIR_RUN_SPECIFIC"

// process {
//   withName: '.*MULTIQC.*' {
//       ext.args = '--max-size 100g'
//   }
// }
EOF

RUN_POST_RUN_SCRIPT="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script.sh"
RUN_POST_RUN_SCRIPT_CALLBACK="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script_callback.sh"
echo "RUN_POST_RUN_SCRIPT_CALLBACK: $RUN_POST_RUN_SCRIPT_CALLBACK"

# Build the callback script that will execute the post-run script
"$(pwd)/UTILS/build_post_run_callback_script.sh" "$RUN_POST_RUN_SCRIPT" "$RUN_POST_RUN_SCRIPT_CALLBACK"

# Launch the run
echo "Launching run: $RUN_NAME_FULL"
tw launch "$PIPELINE_NAME_OR_URL" \
  --name "$RUN_NAME_FULL" \
  --labels "$RUN_LABELS" \
  --compute-env="$COMPUTE_ENV" \
  --profile "$PROFILES" \
  --config $CONFIG_FILE_RUN_SPECIFIC \
  --post-run "${RUN_POST_RUN_SCRIPT_CALLBACK}"

# Capture the workflow run ID of the latest run
WORKFLOW_RUN_ID=$(tw runs list --max 1 | awk 'NF' |  tail -n 1 | awk '{print $1}')

# Build the post run script to copy the run output back to the project directory
"$(pwd)/UTILS/build_post_run_script.sh" "$NXF_LAUNCH_DIR" "$WORKFLOW_RUN_ID" "$NXF_OUTPUT_DIR_RUN_SPECIFIC" "$RUN_POST_RUN_SCRIPT"


################################################################################
# Launch Run 10
################################################################################

# Launch with configuration 10
RUN_NAME="Galderia_yellowstonsis_Assembly_10kb_Downsampled"
RUN_NAME_FULL="${RUN_NAME}_${TIMESTAMP}"
echo "RUN_NAME_FULL: $RUN_NAME_FULL"
RUN_LABELS="yellowstonsis_10kb,time_${TIMESTAMP}"
echo "RUN_LABELS: $RUN_LABELS"
# Input file
INPUT_FILE="/ibex/scratch/projects/c2303/20251019_Galdi-T2T-Assembly/SANGERTOL-TEST/GENOME-ASSEMBLER-TEST_Local_fork_rev_0c2aae85173eba12446e3f325431653e2d697c22/genomeassembly/INPUTS/Galdi_yellowstonsis_gt10kb_samplesheet.yaml"
echo using input file: $INPUT_FILE
cp "$INPUT_FILE" "$NXF_OUTPUT_DIR" # Copy the input file to the output directory

NXF_OUTPUT_DIR_RUN_SPECIFIC="${NXF_OUTPUT_DIR}/${RUN_NAME}"
# Configs
CONFIG_FILE="nextflow.config"
CONFIG_FILE_RUN_SPECIFIC="$(basename $CONFIG_FILE .config).$RUN_NAME.config"
cp $CONFIG_FILE $CONFIG_FILE_RUN_SPECIFIC

# Modify your arguments here
cat << EOF >> "$CONFIG_FILE_RUN_SPECIFIC"
params.input = "$INPUT_FILE"
params.outdir = "$NXF_OUTPUT_DIR_RUN_SPECIFIC"

// process {
//   withName: '.*MULTIQC.*' {
//       ext.args = '--max-size 100g'
//   }
// }
EOF

RUN_POST_RUN_SCRIPT="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script.sh"
RUN_POST_RUN_SCRIPT_CALLBACK="$(pwd)/TMP/${RUN_NAME_FULL}.post_run_script_callback.sh"
echo "RUN_POST_RUN_SCRIPT_CALLBACK: $RUN_POST_RUN_SCRIPT_CALLBACK"

# Build the callback script that will execute the post-run script
"$(pwd)/UTILS/build_post_run_callback_script.sh" "$RUN_POST_RUN_SCRIPT" "$RUN_POST_RUN_SCRIPT_CALLBACK"

# Launch the run
echo "Launching run: $RUN_NAME_FULL"
tw launch "$PIPELINE_NAME_OR_URL" \
  --name "$RUN_NAME_FULL" \
  --labels "$RUN_LABELS" \
  --compute-env="$COMPUTE_ENV" \
  --profile "$PROFILES" \
  --config $CONFIG_FILE_RUN_SPECIFIC \
  --post-run "${RUN_POST_RUN_SCRIPT_CALLBACK}"

# Capture the workflow run ID of the latest run
WORKFLOW_RUN_ID=$(tw runs list --max 1 | awk 'NF' |  tail -n 1 | awk '{print $1}')

# Build the post run script to copy the run output back to the project directory
"$(pwd)/UTILS/build_post_run_script.sh" "$NXF_LAUNCH_DIR" "$WORKFLOW_RUN_ID" "$NXF_OUTPUT_DIR_RUN_SPECIFIC" "$RUN_POST_RUN_SCRIPT"
