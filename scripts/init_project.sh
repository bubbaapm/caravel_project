#!/bin/bash
set -e

# =============================================================================
# init_project.sh
# Master setup script for the ReRAM Caravel User Project
# =============================================================================

SKIP_TOOLS=false
SKIP_CF_SETUP=false
TOOLS_ONLY=false
VERIFY_ONLY=false

for arg in "$@"; do
    case $arg in
        --skip-tools)    SKIP_TOOLS=true ;;
        --skip-cf-setup) SKIP_CF_SETUP=true ;;
        --tools-only)    TOOLS_ONLY=true ;;
        --verify-only)   VERIFY_ONLY=true ;;
        --help)
            head -10 "$0" | tail -6
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=============================================="
echo "  ReRAM Caravel User Project Setup"
echo "=============================================="
echo "Project root: $PROJECT_ROOT"
echo ""

phase_prereqs() {
    echo "Phase 0: Checking prerequisites"
    local ok=true

    if ! command -v apt-get &>/dev/null; then
        echo "  [FAIL] apt-get not found."
        ok=false
    fi

    if ! command -v git &>/dev/null; then
        echo "  [FAIL] git not found."
        ok=false
    fi

    if [ ! -f "$PROJECT_ROOT/Makefile" ]; then
        echo "  [FAIL] Makefile not found. Are you in the project root?"
        ok=false
    fi

    if [ "$ok" = false ]; then
        echo "Prerequisites check failed. Fix the issues and re-run."
        exit 1
    fi
    echo ""
}

phase_install_tools() {
    echo "Phase 1: Installing EDA tools"

    if [ "$SKIP_TOOLS" = true ]; then
        echo "  Skipped (--skip-tools)"
        echo ""
        return
    fi

    bash "$PROJECT_ROOT/scripts/install_tools.sh"

    export PATH="$HOME/.local/bin:$PATH"

    echo "Verifying installed tools..."
    local tools=(magic xschem ngspice netgen openvaf cf)
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            echo "  [OK] $tool"
        else
            echo "  [WARN] $tool not found on PATH"
        fi
    done
    echo ""
}

phase_cf_setup() {
    echo "Phase 2: ChipFoundry CLI project setup"

    if [ "$SKIP_CF_SETUP" = true ]; then
        echo "  Skipped (--skip-cf-setup)"
        echo ""
        return
    fi

    export PATH="$HOME/.local/bin:$PATH"

    if ! command -v cf &>/dev/null; then
        echo "  [FAIL] cf command not found. Run without --skip-tools first."
        exit 1
    fi

    source "$PROJECT_ROOT/setup.sh"

    if [ ! -f "$PROJECT_ROOT/.cf/project.json" ]; then
        echo "  Running cf init..."
        cf init
    else
        echo "  [OK] .cf/project.json already exists"
    fi

    if [ ! -d "$PDK_ROOT/sky130B" ]; then
        echo "  Running cf setup --pdk sky130B (this will take a while)..."
        cf setup --pdk sky130B
    else
        echo "  [OK] PDK sky130B already installed"
    fi

    local cf_ok=true
    for dir in "caravel" "dependencies/pdks/sky130B" "dependencies/openlane_src"; do
        if [ ! -d "$PROJECT_ROOT/$dir" ]; then
            echo "  [WARN] $dir not found"
            cf_ok=false
        fi
    done

    if [ "$cf_ok" = false ]; then
        echo "  Some directories are missing. cf setup may not have completed fully."
    fi
    echo ""
}

phase_reram_osdi() {
    echo "Phase 3: ReRAM ngspice OSDI model setup"

    source "$PROJECT_ROOT/setup.sh"
    local OSDI_TARGET="${PDK_ROOT}/sky130B/libs.tech/combined/sky130_fd_pr_reram__reram_module.osdi"

    if [ -f "$OSDI_TARGET" ]; then
        echo "  [OK] ReRAM OSDI model already installed"
        echo ""
        return
    fi

    if [ ! -d "$PDK_ROOT/sky130B" ] || ! command -v openvaf &>/dev/null; then
        echo "  [FAIL] Missing PDK or OpenVAF. Run previous phases first."
        exit 1
    fi

    echo "  Cloning and compiling ReRAM model..."
    local RERAM_TMPDIR=$(mktemp -d)
    trap "rm -rf $RERAM_TMPDIR" RETURN

    git clone https://github.com/barakhoffer/sky130_ngspice_reram.git "$RERAM_TMPDIR/sky130_ngspice_reram"
    cd "$RERAM_TMPDIR/sky130_ngspice_reram"

    git clone https://github.com/google/skywater-pdk-libs-sky130_fd_pr_reram sky130_fd_pr_reram
    cp sky130_fd_pr_reram/cells/reram_cell/sky130_fd_pr_reram__reram_cell.va ngspice/sky130_fd_pr_reram__reram_module.va

    patch "ngspice/sky130_fd_pr_reram__reram_module.va" < "ngspice/va_model_patch"
    openvaf ngspice/sky130_fd_pr_reram__reram_module.va

    sed -i "s|/foss/pdks|$PDK_ROOT|g" ngspice/sky130_fd_pr_reram__reram_cell.spice
    sed -i "s|/foss/pdks|$PDK_ROOT|g" ngspice/reram_example.spice

    echo "  Installing into PDK..."
    sudo mkdir -p "${PDK_ROOT}/sky130B/libs.tech/ngspice"
    sudo cp ngspice/*.va "${PDK_ROOT}/sky130B/libs.tech/ngspice/"
    sudo cp ngspice/*.spice "${PDK_ROOT}/sky130B/libs.tech/ngspice/"
    sudo cp ngspice/*.osdi "${PDK_ROOT}/sky130B/libs.tech/ngspice/"

    sudo mkdir -p "${PDK_ROOT}/sky130B/libs.tech/combined"
    sudo cp ngspice/*.osdi "${PDK_ROOT}/sky130B/libs.tech/combined/"

    if [ -d "xschem" ]; then
        sudo cp -r xschem "${PDK_ROOT}/sky130B/libs.tech/"
    fi

    sudo chown -R $USER:$USER "${PDK_ROOT}"
    cd "$PROJECT_ROOT"
    echo "  [OK] ReRAM OSDI model installed"
    echo ""
}

phase_config_files() {
    echo "Phase 4: Configuring project RC files"

    source "$PROJECT_ROOT/setup.sh"

    mkdir -p "$PROJECT_ROOT/mag"
    if [ ! -f "$PROJECT_ROOT/mag/.magicrc" ]; then
        echo "  Copying .magicrc from PDK"
        cp "$PDK_ROOT/sky130B/libs.tech/magic/sky130B.magicrc" "$PROJECT_ROOT/mag/.magicrc"
    fi

    mkdir -p "$PROJECT_ROOT/xschem"
    if [ ! -f "$PROJECT_ROOT/xschem/xschemrc" ]; then
        echo "  Copying xschemrc from PDK"
        cp "$PDK_ROOT/sky130B/libs.tech/xschem/xschemrc" "$PROJECT_ROOT/xschem/"
    fi

    if [ ! -f "$PROJECT_ROOT/mag/sky130B_setup.tcl" ]; then
        echo "  Copying netgen setup.tcl from PDK"
        cp "$PDK_ROOT/sky130B/libs.tech/netgen/sky130B_setup.tcl" "$PROJECT_ROOT/mag/sky130B_setup.tcl"
    fi

    local exec_files=("mag/LVS" "mag/start_magic.sh")
    for f in "${exec_files[@]}"; do
        if [ -f "$PROJECT_ROOT/$f" ] && [ ! -x "$PROJECT_ROOT/$f" ]; then
            chmod +x "$PROJECT_ROOT/$f"
        fi
    done

    mkdir -p "$HOME/.xschem/simulations"
    echo ""
}

phase_verify() {
    echo "Phase 5: Verification summary"
    source "$PROJECT_ROOT/setup.sh"
    
    local pass=0
    local fail=0

    check() {
        if eval "$2" &>/dev/null; then
            echo "  [PASS] $1"
            ((pass++))
        else
            echo "  [FAIL] $1"
            ((fail++))
        fi
    }

    check "Tools installed" "command -v magic && command -v xschem && command -v ngspice && command -v openvaf && command -v cf"
    check "PDK tech file exists" "test -f $PDK_ROOT/sky130B/libs.tech/magic/sky130B.tech"
    check "ReRAM OSDI model exists" "test -f $PDK_ROOT/sky130B/libs.tech/combined/sky130_fd_pr_reram__reram_module.osdi"
    check "Caravel installed" "test -d $CARAVEL_ROOT"
    check "Project Magic config exists" "test -f $PROJECT_ROOT/mag/.magicrc"
    check "Project Xschem config exists" "test -f $PROJECT_ROOT/xschem/xschemrc"

    echo "  Results: $pass passed, $fail failed"
    echo ""
}

phase_finalize() {
    echo "Phase 6: Finalizing Environment"

    if [ ! -d "caravel_env" ]; then
        python3 -m venv caravel_env
    fi

    if ! grep -q 'direnv hook bash' ~/.bashrc; then
        echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
    fi

    echo "source caravel_env/bin/activate" > "$PROJECT_ROOT/.envrc"
    echo "source setup.sh" >> "$PROJECT_ROOT/.envrc"
    direnv allow "$PROJECT_ROOT"

    echo "=============================================="
    echo "  SETUP COMPLETE - RESTARTING SHELL"
    echo "=============================================="
    exec sg docker -c "exec bash"
}

# Execution
if [ "$VERIFY_ONLY" = true ]; then
    phase_verify
    exit 0
fi

phase_prereqs

if [ "$TOOLS_ONLY" = true ]; then
    phase_install_tools
    exit 0
fi

phase_install_tools
phase_cf_setup
phase_reram_osdi
phase_config_files
phase_verify
phase_finalize
