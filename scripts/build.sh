#!/bin/sh

[ "$#" -eq 0 ] && echo '1st arg (source) is required.' && exit 1

CURRENT_DIR=$PWD
# locate
if [ -z "$BASH_SOURCE" ]; then
    SCRIPT_DIR=`dirname "$(readlink -f $0)"`
elif [ -e '/bin/zsh' ]; then
    F=`/bin/zsh -c "print -lr -- $BASH_SOURCE(:A)"`
    SCRIPT_DIR=`dirname $F`
elif [ -e '/usr/bin/realpath' ]; then
    F=`/usr/bin/realpath $BASH_SOURCE`
    SCRIPT_DIR=`dirname $F`
else
    F=$BASH_SOURCE
    while [ -h "$F" ]; do F="$(readlink $F)"; done
    SCRIPT_DIR=`dirname $F`
fi

function follow_symlink() {
    UNAME=`uname`
    case "$UNAME" in
        Darwin)
        /bin/zsh -c "print -lr -- $1(:A)"
        ;;
        *)
        readlink -f "$1"
        ;;
    esac
}

BASE_DIR=`dirname $SCRIPT_DIR`

SRC_ARG="$1"
SRC_RUN=
[ "$#" -gt 1 ] && SRC_RUN=1 && shift
shift

# canonical src path
SRC_PATH=`follow_symlink $SRC_ARG`
SRC_DIR=`dirname $SRC_PATH`
SRC_FILE=$(basename -- "$SRC_PATH")
SRC_NAME="${SRC_FILE%.*}"

OUT_DIR=target

LLVM_DIR=$BASE_DIR/llvm-project
SYSROOT_DIR=$BASE_DIR/wali-musl/sysroot

RT_LIB=$LLVM_DIR/build/lib/clang/16/lib/wasi/libclang_rt.builtins-wasm32.a

CC=$LLVM_DIR/build/bin/clang
LD=$LLVM_DIR/build/bin/wasm-ld

OUT_TMP=$OUT_DIR/tmp/$SRC_NAME
OUT_BIN=$OUT_DIR/$SRC_NAME

mkdir -p $OUT_DIR/tmp

CRT_FILE=$SYSROOT_DIR/lib/crt1.o

$CC --target=wasm32-wasi-threads -O1 -pthread --sysroot=$SYSROOT_DIR $SRC_PATH -c -o $OUT_TMP.int.wasm

wasm2wat --enable-threads $OUT_TMP.int.wasm -o $OUT_TMP.int.wat
$LD --no-gc-sections --no-entry --shared-memory --export-memory --max-memory=67108864 \
--allow-undefined -L$SYSROOT_DIR/lib $OUT_TMP.int.wasm $CRT_FILE -lc -lm $RT_LIB -o $OUT_BIN.wasm

[ "$WITH_WAT" = '1' ] && wasm2wat --enable-threads $OUT_BIN.wasm -o $OUT_TMP.wat

[ -z "$SRC_RUN" ] && exit 0

ENV_FILE=target/env.txt
[ -e "$ENV_FILE" ] || touch $ENV_FILE

iwasm --env-file=$ENV_FILE $OUT_BIN.wasm $@
