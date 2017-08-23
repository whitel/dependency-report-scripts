#!/bin/sh
arches=$(cat arches.txt)
base=modules

echo ""
echo "Visualizing dependencies between modules..."

mkdir -p img
> img/module-deps.dot
echo "digraph G {" >> img/module-deps.dot
echo "  node [fontname=monospace];" >> img/module-deps.dot

for module in $(ls modules); do
    for dep in $(cat modules/$module/modular-deps.txt); do
        echo "  \"$module\" -> \"$dep\" [color=\"#009900\"];" >> img/module-deps.dot
    done 
    for dep in $(cat modules/$module/modular-build-deps.txt); do
        echo "  \"$module\" -> \"$dep\" [color=\"#aa0000\"];" >> img/module-deps.dot
    done 
done

echo "}" >> img/module-deps.dot

dot -Tpng img/module-deps.dot > img/module-deps.png


echo ""
echo "Generating combined arch lists..."
files="
    runtime-binary-packages-short.txt
    runtime-source-packages-short.txt
    buildtime-binary-packages-short.txt
    buildtime-source-packages-short.txt
    runtime-source-packages-full.txt"

for file in $files; do
    for module in $(ls modules); do
        mkdir -p $base/$module/all
        for arch in $arches; do
            cat $base/$module/$arch/$file
        done \
            | sort -u \
            > $base/$module/all/$file
    done
done
         
echo ""
echo "Generating reports in README for each module..."
for module in $(ls modules); do
    {
        cat << EOF
# $module
This is a dependency report for the $module module.

An initial [modulemd file]($module.yaml) has been generated. It is experimental and probably unusable at this point.
## Dependencies
These are modules identified as dependencies.
### Runtime
This list might not be complete. There might be other packages in the *Binary RPM packages (all arches combined)* section that needs to be split to different modules.
EOF
        for dep in $(cat modules/$module/modular-deps.txt); do
            echo "* [$dep](../$dep)"
        done
        cat << EOF
### Build
This list might not be complete.
Please see the **missing RPM build dependencies ([source](all/buildtime-source-packages-short.txt) or [binary](all/buildtime-binary-packages-short.txt)) lists** for more information.
EOF
        for dep in $(cat modules/$module/modular-build-deps.txt); do
            echo "* [$dep](../$dep)"
        done
        cat << EOF
## Binary RPM packages
These are RPM dependencies of the [$module top-level package set]($module.csv). They should be either:
* split into other modules and be used as modular dependencies
* included in this $module module
### Packages
EOF

        printf "| |"
        for arch in $(cat arches.txt); do
            printf "$arch |"
        done
        printf "\n"

        printf "%s" "|---|"
        for arch in $(cat arches.txt); do
            printf "%s" "---|"
        done
        printf "\n"

        for pkg in $(cat modules/$module/all/runtime-binary-packages-short.txt); do
            printf "| \`$pkg\` |"
            for arch in $(cat arches.txt); do
                cat modules/$module/$arch/runtime-binary-packages-short.txt | grep "^$pkg$" > /dev/null
                if [ $? -eq 0 ]; then
                    printf " X |"
                else
                    printf " - |"
                fi
            done
            printf "\n"
        done
    } > modules/$module/README.md
done

echo ""
echo "Generating modulemd files..."

modulemd_modules=$(ls modules \
    | sed \
        -e "s/^bootstrap$//g" \
        -e "s/^platform$//g" \
        -e "s/^platform-placeholder$//g")
for module in $modulemd_modules; do
    {
        cat << EOF
document: modulemd
version: 1
data:
    summary: $module module
    description: This $module has been generated
    license:
        module: [ MIT ]
    dependencies:
        buildrequires:
EOF
        for dep in $(cat modules/$module/modular-build-deps.txt); do
            echo "            $dep: master"
        done
        cat << EOF
        requires:
EOF
        for dep in $(cat modules/$module/modular-deps.txt); do
            echo "            $dep: master"
        done
        cat << EOF
    references:
        community: https://docs.pagure.org/modularity/
        documentation: https://github.com/modularity-modules/$module
        tracker: https://github.com/modularity-modules/$module
    components:
        rpms:
EOF
        for pkg in $(cat modules/$module/all/runtime-source-packages-short.txt); do
            cat << EOF
            $pkg:
                rationale: Generated.
                ref: master.
EOF
        done
    } > modules/$module/$module.yaml
done

