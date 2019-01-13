#!/bin/bash
unknown_params_action=set
. $DLBS_ROOT/scripts/parse_options.sh || exit 1;    # Parse command line options
. $DLBS_ROOT/scripts/utils.sh
loginfo "$0 $*" >> ${exp_log_file}                  # Log command line arguments for debugging purposes
echo "__exp.framework_title__=\"PyTorch\"" >> ${exp_log_file}
if [ "$exp_status" = "simulate" ]; then
    echo "${pytorch_env} ${runtime_launcher} python ${pytorch_bench_path}/pytorch_benchmarks/benchmarks.py ${pytorch_args}"
    exit 0
fi
# Check batch is small enough for this experiment
__batch_file__="$(dirname ${exp_log_file})/${exp_framework}_${exp_device_type}_${exp_model}.batch"
if [ "${exp_ignore_past_errors}" != "true" ]; then
  is_batch_good "${__batch_file__}" "${exp_replica_batch}" || {
    report_and_exit "skipped" "The replica batch size (${exp_replica_batch}) is too large for given SW/HW configuration." "${exp_log_file}";
  }
fi
# This script is to be executed inside docker container or on a host machine.
# Thus, the environment must be initialized inside this scrip lazily.
if [ "${exp_num_nodes}" == "1" ]; then
  if [ "${exp_num_gpus}" == "1" ]; then
      bench_launcher=""
  else
      if [ "${exp_device_type}" == "gpu" ]; then
          bench_launcher="-m torch.distributed.launch --nproc_per_node=${exp_num_local_gpus}"
      else
          bench_launcher="-m torch.distributed.launch --nproc_per_node=1"
      fi
  fi
else
  bench_launcher="-m torch.distributed.launch --nnodes=${exp_num_nodes} --node_rank=${pytorch_distributed_rank}"
  bench_launcher="${bench_launcher} --master_addr=${pytorch___master_addr} --master_port=${pytorch___master_port}"
  bench_launcher="${bench_launcher} --nproc_per_node=${exp_num_local_gpus}"
  #echo "Bench launcher: ${bench_launcher}"
fi

[ -z "${runtime_launcher}" ] && runtime_launcher=":;"

script="\
    export ${pytorch_env};\
    echo -e \"__results.start_time__= \x22\$(date +%Y-%m-%d:%H:%M:%S:%3N)\x22\";\
    ${runtime_launcher} ${runtime_python} ${bench_launcher} ${pytorch_bench_path}/pytorch_benchmarks/benchmarks.py ${pytorch_args} &\
    proc_pid=\$!;\
    [ \"${monitor_frequency}\" != \"0\" ] && echo -e \"\${proc_pid}\" > ${monitor_backend_pid_folder}/proc.pid;\
    wait \${proc_pid};\
    echo -e \"__results.end_time__= \x22\$(date +%Y-%m-%d:%H:%M:%S:%3N)\x22\";\
    echo -e \"__results.proc_pid__= \${proc_pid}\";\
"
if [ "${exp_docker}" = "true" ]; then
    assert_docker_img_exists "${exp_docker_image}" "${exp_docker_launcher}"
    ${exp_docker_launcher} run ${pytorch_docker_args} /bin/bash -c "eval $script" >> ${exp_log_file} 2>&1
else
    eval $script >> ${exp_log_file} 2>&1
fi

