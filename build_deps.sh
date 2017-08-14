#!/bin/sh
arches="aarch64 armv7hl i686 ppc64 ppc64le s390x x86_64"
files="
    binary-packages-full.txt
    binary-packages-short.txt
    source-packages-full.txt
    source-packages-short.txt"
target=$1
shift
deps=$@
base=modules

for file in $files; do
    for arch in $arches; do
        for dep in $deps; do
            cat $base/$dep/$arch/runtime-complete-$file
        done \
            | sort -u \
            | comm -23 $base/$target/$arch/complete-buildtime-$file - \
            > $base/$target/$arch/buildtime-$file
    done
done

echo $deps | sed -e "s/ /\n/g" > $base/$target/modular-build-deps.txt