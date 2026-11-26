#!/bin/bash
set -e

# https://community.openhab.org/t/user-creation-management-on-initial-start-of-openhab-on-docker-kubernetes/141654/12
# Ensure that the openhab user is used as otherwise some files receive wrong ownership and the main instance of
# openHAB fails to start at the end to the Docker entrypoint
/bin/bash -c "su-exec openhab /openhab/runtime/bin/start"
sleep 40
# Explicitly install ESPHome binding for the Native API, since it sometimes doesn't survive Docker container updates
sshpass -p habopen ssh -o StrictHostKeyChecking=no -p 8101 openhab@localhost "openhab:addons install marketplace:146849"
# Show INFO level log messages from openhab-heating-optimizer
sshpass -p habopen ssh -o StrictHostKeyChecking=no -p 8101 openhab@localhost "log:set INFO openhab.heating.optimizer"
/bin/bash -c "su-exec openhab /openhab/runtime/bin/stop"
sleep 40

find_java_pids() {
    java_pids=()
    for proc in /proc/[0-9]*; do
        [[ -r "$proc/comm" ]] || continue
        IFS= read -r comm < "$proc/comm" || continue
        [[ "$comm" == "java" ]] && java_pids+=("${proc##*/}")
    done
}

find_java_pids
if ((${#java_pids[@]} == 0)); then
    echo "No Java processes found after stopping openHAB."
else
    echo "Found Java process(es) after stopping openHAB: ${java_pids[*]}; sending SIGTERM."
    for pid in "${java_pids[@]}"; do
        kill -TERM "$pid" 2>/dev/null || true
    done

    for ((attempt = 0; attempt < 10; attempt++)); do
        sleep 1
        find_java_pids
        ((${#java_pids[@]} == 0)) && break
    done

    if ((${#java_pids[@]} > 0)); then
        echo "Java process(es) still running: ${java_pids[*]}; sending SIGKILL."
        for pid in "${java_pids[@]}"; do
            kill -KILL "$pid" 2>/dev/null || true
        done
        sleep 1
        find_java_pids
        if ((${#java_pids[@]} > 0)); then
            echo "ERROR: Java process(es) remain after SIGKILL: ${java_pids[*]}." >&2
            exit 1
        fi
    fi
    echo "All Java processes have terminated."
fi

# Forcibly clear cache as the JavaScript engine or the heating optimizer addon frequently get
# stuck after even just a patch level update of openHAB
rm -rf /openhab/userdata/tmp/*
rm -rf /openhab/userdata/cache/*