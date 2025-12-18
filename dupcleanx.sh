#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

#  Globals
SCAN_DIR=""
REPORT_FILE="/home/mahin_231902056/Music/dupcleanx-report.txt"
EMPTY_FILE="/home/mahin_231902056/Music/dupcleanx-empty.txt"

# helpers (Linux/macOS)
stat_size() {
  if stat --version >/dev/null 2>&1; then
    # Linux
    stat -c%s -- "$1"
  else
    # macOS
    stat -f%z -- "$1"
  fi
}

md5_hash() {
  if command -v md5sum >/dev/null 2>&1; then
    md5sum -- "$1" | awk '{print $1}'
  else
    md5 -r -- "$1" | awk '{print $1}'
  fi
}

# Convert size to human readable
human_size() {
  local size=$1
  if [[ "$size" -lt 1024 ]]; then
    printf "%s B" "$size"
  elif [[ "$size" -lt 1048576 ]]; then
    printf "%s KB" "$((size / 1024))"
  elif [[ "$size" -lt 1073741824 ]]; then
    printf "%s MB" "$((size / 1048576))"
  else
    printf "%s GB" "$((size / 1073741824))"
  fi
}

# UI & Headers
print_header() {
  printf "%b\n" "${BLUE}======================================${RESET}"
  printf "%b\n" "${GREEN}      Duplicate File Finder and Cleaner  ${RESET}"
  printf "%b\n" "${BLUE}======================================${RESET}"
}

exit_program() {
  printf "%b" "\n${RED}✖ Exiting ...${RESET}\n"
  printf "%b" "${CYAN}Thank you for using Duplicate File Finder and Cleaner!${RESET}\n"
  printf "%b" "${GREEN}* Goodbye *${RESET}\n\n"
  exit 0
}

# Directory Input
read_directory() {
  while true; do
    read -r -p "Enter directory path to scan: " SCAN_DIR
    [[ "${SCAN_DIR}" == "exit" ]] && exit_program
    if [[ -d "${SCAN_DIR}" ]]; then
      return
    fi
    printf "%b" "${RED}✖ Invalid directory.${RESET}\n"
    printf "%b" "${CYAN}Please enter a valid path (e.g. ${YELLOW}/home/user/Music${CYAN}).${RESET}\n"
  done
}

#  Scanning Function
scan_duplicates() {
  : > "${REPORT_FILE}"
  : > "${EMPTY_FILE}"

  local tmp_hash
  tmp_hash="$(mktemp /tmp/dupcleanx-hash.XXXXXX)"

  printf "%b\n" "${YELLOW}Scanning directory: ${SCAN_DIR} ...${RESET}"

  # Collect files using null delim to handle special chars/newlines safely
  local -a files_list=()
  while IFS= read -r -d '' f; do files_list+=("$f"); done < <(find "${SCAN_DIR}" -type f -print0)
  local total_files=${#files_list[@]} processed=0

  if (( total_files == 0 )); then
    printf "%b" "${RED}No files found in directory.${RESET}\n"
    rm -f -- "${tmp_hash}"
    return
  fi

  # Progress bar settings
  local bar_width=50

  for file in "${files_list[@]}"; do
    local size hash
    size="$(stat_size "$file")"
    if [[ "$size" -eq 0 ]]; then
      printf "%s\n" "$file" >> "${EMPTY_FILE}"
    else
      hash="$(md5_hash "$file")"
      printf "%s\t%s\t%s\n" "${hash}" "${size}" "${file}" >> "${tmp_hash}"
    fi

    processed=$((processed + 1))
    local percent=$((processed * 100 / total_files))
    local filled=$((percent * bar_width / 100))
    # build a bar without seq
    local bar=""
    if (( filled > 0 )); then
      printf -v bar "%*s" "${filled}" ""
      bar="${bar// /#}"
    fi
    local spaces=$((bar_width - filled))
    local pad=""
    if (( spaces > 0 )); then
      printf -v pad "%*s" "${spaces}" ""
    fi
    printf "\r%b" "${CYAN}Progress:${RESET} [${bar}${pad}] $(printf "%3d" "${percent}")%"
  done

  printf "\n%b" "${GREEN}✔ Scanning completed!${RESET}\n"

  LC_ALL=C sort "${tmp_hash}" > "${tmp_hash}.sorted"
  mv -f -- "${tmp_hash}.sorted" "${tmp_hash}"

  group_duplicates "${tmp_hash}"
  rm -f -- "${tmp_hash}"
}

# Grouping Duplicates
group_duplicates() {
  local tmp_hash=$1
  local current_hash=""
  local -a files=()
  local group_count=0

  while IFS=$'\t' read -r hash size path; do
    if [[ "${hash}" == "${current_hash}" ]]; then
      files+=("${size}|${path}")
    else
      if (( ${#files[@]} > 1 )); then
        group_count=$((group_count + 1))
        for f in "${files[@]}"; do
          printf "%s|%s\n" "${group_count}" "${f}" >> "${REPORT_FILE}"
        done
      fi
      current_hash="${hash}"
      files=("${size}|${path}")
    fi
  done < "${tmp_hash}"

  if (( ${#files[@]} > 1 )); then
    group_count=$((group_count + 1))
    for f in "${files[@]}"; do
      printf "%s|%s\n" "${group_count}" "${f}" >> "${REPORT_FILE}"
    done
  fi

  # Summary
  local -a empty_dirs=()
  while IFS= read -r d; do empty_dirs+=("$d"); done < <(find "${SCAN_DIR}" -type d -empty -print)
  printf "%b" "${GREEN}✔ Scan complete:${RESET} ${YELLOW}${group_count}${RESET} duplicate group(s) found.\n"
  printf "%b" "${CYAN}Empty Folders:${RESET} ${#empty_dirs[@]}, ${CYAN}Empty Files:${RESET} $(wc -l < "${EMPTY_FILE}")\n"
}

# Display Groups & Empty Items
show_groups_and_empty() {
  local last_group=0

  if [[ -s "${REPORT_FILE}" ]]; then
    printf "\n%b\n" "${BLUE}Duplicate Groups:${RESET}"
    local g
    for g in $(awk -F'|' '{print $1}' "${REPORT_FILE}" | sort -nu); do
      local -a files=()
      while IFS='|' read -r grp size path; do
        [[ "${grp}" == "${g}" ]] && files+=("${size}|${path}")
      done < "${REPORT_FILE}"

      local first_file="${files[0]##*|}"
      local first_size="${files[0]%%|*}"
      
      #printf "\n%b" "$(printf "%b" "${YELLOW}╔═══ Group %02d ═══╗${RESET}\n" "${g}")"
      printf "\n${YELLOW}╔═══ Group %02d ═══╗${RESET}\n" "$g"
      printf " %b %b  (%b %s%b %s)\n" \
      "${CYAN}-->${RESET}" \
      "${GREEN}Original:${RESET} $(basename -- "$first_file")" \
      "${BLUE}" "size:" "${RESET}" "$(human_size "$first_size")"

      printf "     %b\n" "${BLUE}(Original file location)${RESET}"
      printf "     %s\n" "$first_file"


      if (( ${#files[@]} > 1 )); then
        printf "   %b\n" "${GREEN}List of Duplicates:${RESET}"
        local i
        for ((i = 1; i < ${#files[@]}; i++)); do
          printf "      %d) %s\n" "$i" "${files[$i]##*|}"
        done
      fi
      printf "\n   Total duplicate files : %b%d%b\n\n" "${RED}" "$(( ${#files[@]} - 1 ))" "${RESET}"
      last_group=${g}
    done
  fi

  local -a empty_dirs=()
  while IFS= read -r d; do empty_dirs+=("$d"); done < <(find "${SCAN_DIR}" -type d -empty -print)
  local empty_files_count
  empty_files_count=$(find "${SCAN_DIR}" -type f -empty | wc -l | awk '{print $1}')

  if (( ${#empty_dirs[@]} > 0 )) || [[ "${empty_files_count}" -gt 0 ]] || [[ -s "${REPORT_FILE}" ]]; then
    show_empty_folders_and_files "${last_group}"
  else
    printf "\n%b" "${CYAN}Now no Group Available${RESET}\n"
    exit_program
  fi
}

# Show Empty Folders / Files
show_empty_folders_and_files() {
  local last_group=$1
  local -a empty_dirs=()
  while IFS= read -r d; do empty_dirs+=("$d"); done < <(find "${SCAN_DIR}" -type d -empty -print)

  if (( ${#empty_dirs[@]} > 0 )); then
    printf "\n%b" "$(printf "${YELLOW}╔═══ Group %02d ═══╗${RESET}\n" "$((last_group + 1))")"
    printf "%b\n" "${BLUE}  Empty Folders ${RESET}"
    local i
    for i in "${!empty_dirs[@]}"; do
      printf "    %d) %s\n" "$((i + 1))" "${empty_dirs[$i]}"
    done
    printf "    Total empty folders: %d\n" "${#empty_dirs[@]}"
  fi

  if [[ -s "${EMPTY_FILE}" ]]; then
    printf "\n%b" "$(printf "${YELLOW}╔═══ Group %02d ═══╗${RESET}\n" "$((last_group + 2))")"
    printf "%b\n" "${BLUE}  Empty Files ${RESET}"
    nl -ba -- "${EMPTY_FILE}"
    printf "    Total empty files: %s\n" "$(wc -l < "${EMPTY_FILE}")"
  fi
}

#  Cleaning Functions
clean_group() {
  local -a empty_dirs=()
  while IFS= read -r d; do empty_dirs+=("$d"); done < <(find "${SCAN_DIR}" -type d -empty -print)

  local last_dup_group folder_group file_group
  last_dup_group="$(awk -F'|' '{print $1}' "${REPORT_FILE}" | sort -nu | tail -n1 2>/dev/null || echo 0)"
  folder_group=$((last_dup_group + 1))
  # no ternary operator in bash arithmetic; do it the boring way:
  if (( ${#empty_dirs[@]} > 0 )); then
    file_group=$((folder_group + 1))
  else
    file_group=$((folder_group))
  fi

  while true; do
    printf "\n%b\n" "${YELLOW}Available Groups:${RESET}"
    local g
    for g in $(awk -F'|' '{print $1}' "${REPORT_FILE}" | sort -nu); do
      local file
      file="$(awk -F'|' -v grp="$g" '$1==grp {print $3; exit}' "${REPORT_FILE}")"
      printf "  Group %02d : %s\n" "$g" "$(basename -- "$file")"
    done
    (( ${#empty_dirs[@]} > 0 )) && printf "  Group %02d : Empty Folders\n" "$folder_group"
    [[ -s "${EMPTY_FILE}" ]] && printf "  Group %02d : Empty Files\n" "$file_group"

    printf "%b" "${YELLOW}Enter group number to clean (example: 1 or 01): ${RESET}"
    read -r gnum
    [[ "${gnum}" == "exit" ]] && exit_program
    if [[ ! "${gnum}" =~ ^[0-9]+$ ]]; then
      printf "\n%b" "${RED}✖ Invalid input!${RESET}\n"
      continue
    fi
    # normalize octal-like 01 to decimal
    gnum=$((10#${gnum}))
    perform_clean "${gnum}" "${folder_group}" "${file_group}" "${empty_dirs[@]}"
    return
  done
}

# Actual Cleaning
perform_clean() {
  local gnum=$1 folder_group=$2 file_group=$3; shift 3
  local empty_dirs=("$@")

  # Clean Empty Folder Group
  if [[ "${gnum}" -eq "${folder_group}" && ${#empty_dirs[@]} -gt 0 ]]; then
    local dir
    printf "%b %s\n" "${GREEN} empty folder ${RESET}"
    for dir in "${empty_dirs[@]}"; do
      if rmdir -- "${dir}" 2>/dev/null; then
        printf "%b %s\n" "${RED}Deleted ${RESET}" "${dir}"
      fi
    done
    printf "\n%b" "${GREEN}✔ All empty folders deleted.${RESET}\n"
    echo ""
    check_and_exit
    return
  fi

  #  Clean Empty File Group
  if [[ "${gnum}" -eq "${file_group}" && -f "${EMPTY_FILE}" && -s "${EMPTY_FILE}" ]]; then
    local file
    printf "%b %s\n" "${GREEN} empty file ${RESET}"
    while IFS= read -r file; do
      if [[ -f "${file}" ]]; then
        rm -f -- "${file}"
        printf "%b %s\n" "${RED}Deleted ${RESET}" "${file}"
      fi
    done < "${EMPTY_FILE}"
    : > "${EMPTY_FILE}"
    printf "\n%b" "${GREEN}✔ All empty files deleted.${RESET}\n"
    echo ""
    check_and_exit
    return
  fi

  # Clean Duplicate Group
  if ! grep -q "^${gnum}|" "${REPORT_FILE}"; then
    printf "\n%b" "${RED}✖ Invalid group number!${RESET}\n"
    return
  fi

  local -a files=()
  while IFS='|' read -r grp size path; do
    [[ "${grp}" == "${gnum}" ]] && files+=("${size}|${path}")
  done < "${REPORT_FILE}"

  local first_file="${files[0]##*|}" first_size="${files[0]%%|*}"
  #printf "\n%b\n" "$(printf "%b" "${BLUE}Cleaning group %02d...${RESET}" "${gnum}")"
  printf "\n${BLUE}Cleaning group %02d...${RESET}\n" "$gnum"

  printf "%b %s (%b %s%b %s)\n" "${GREEN}Original file kept:${RESET}" "$(basename -- "$first_file")" "${BLUE}" "size:" "${RESET}" "$(human_size "$first_size")"

  local f path
  for f in "${files[@]:1}"; do
    path="${f##*|}"
    if [[ -f "${path}" ]]; then
      rm -f -- "${path}"
      printf "%b %s\n" "${RED}Deleted:${RESET}" "${path}"
    fi
  done

  # Update Report File
  grep -v "^${gnum}|" "${REPORT_FILE}" > "${REPORT_FILE}.tmp" || true
  mv -f -- "${REPORT_FILE}.tmp" "${REPORT_FILE}"

  #printf "%b\n" "$(printf "%b" "${GREEN}✔ Group %02d deleted successfully.${RESET}" "${gnum}")"
  printf "${GREEN}✔ Group %02d deleted successfully.${RESET}\n" "$gnum"

  echo ""
  check_and_exit
}

# Smart Exit Checker (Safe for nounset)
check_and_exit() {
  local has_dupes=false
  local has_empty_files=false
  local has_empty_dirs=false

  if [[ -s "${REPORT_FILE:-}" ]]; then has_dupes=true; fi
  if [[ -f "${EMPTY_FILE:-}" && -s "${EMPTY_FILE:-}" ]]; then has_empty_files=true; fi
  if [[ -n "$(find "${SCAN_DIR:-.}" -type d -empty -print -quit 2>/dev/null)" ]]; then has_empty_dirs=true; fi

  if [[ "${has_dupes}" == false && "${has_empty_files}" == false && "${has_empty_dirs}" == false ]]; then
    echo
    printf "%b" "${CYAN}Now no Group Available${RESET}\n"
    printf "%b" "${GREEN}✅ All duplicate groups, empty files, and empty folders have been cleaned.${RESET}\n"
    exit_program
  fi
}

#  Main
main() {
  print_header
  read_directory
  scan_duplicates
  show_groups_and_empty

  while true; do
    read -r -p "Do you want to clean any group (duplicate/empty)? [y/N]: " answer
    if [[ "${answer}" =~ ^[Yy]$ ]]; then
      clean_group
    else
      exit_program
    fi
  done
}

main
