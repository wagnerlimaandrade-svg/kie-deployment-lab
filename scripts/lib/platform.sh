#!/usr/bin/env bash

# Shared host-platform helpers. This file is sourced by the executable scripts.

kie_lab_is_windows_bash() {
  case "$(uname -s 2>/dev/null || true)" in
    MINGW* | MSYS* | CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

kie_lab_native_path() {
  local path="$1"

  if kie_lab_is_windows_bash; then
    if ! command -v cygpath >/dev/null 2>&1; then
      echo "ERROR: cygpath is required when running from Git Bash on Windows." >&2
      return 1
    fi
    cygpath --windows "${path}"
  else
    printf '%s\n' "${path}"
  fi
}

kie_lab_stop_process() {
  local process_id="$1"

  if [[ -z "${process_id}" ]] || ! kill -0 "${process_id}" 2>/dev/null; then
    return 0
  fi

  kill "${process_id}" 2>/dev/null || true

  for _ in {1..20}; do
    if ! kill -0 "${process_id}" 2>/dev/null; then
      wait "${process_id}" 2>/dev/null || true
      return 0
    fi
    sleep 0.1
  done

  # Native Windows processes can outlive the MSYS wrapper process. Use the
  # Windows process-tree command only as a fallback when the PID remains alive.
  if kie_lab_is_windows_bash; then
    MSYS2_ARG_CONV_EXCL='*' taskkill.exe /PID "${process_id}" /T /F \
      >/dev/null 2>&1 || true
  else
    kill -KILL "${process_id}" 2>/dev/null || true
  fi

  wait "${process_id}" 2>/dev/null || true
}

