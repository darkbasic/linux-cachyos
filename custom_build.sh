#!/bin/bash

# Define the kernels to modify
kernels=("linux-cachyos" "linux-cachyos-rc")

for kernel in "${kernels[@]}"; do
    echo "Processing kernel: $kernel"

    # Extract patches from raw emails
    for i in {1..7}; do
      infile=$(printf "%02d.txt" "$i")
      outfile=$(printf "000%d-amd-isp4-patch.patch" "$i")
      # Use $HOME instead of ~ inside quotes for correct path expansion
      formail -ds < "$HOME/Downloads/${infile}" | sed '/^--- /,$!d' > "$kernel/$outfile"
      echo "Created ${outfile} from ${infile} in $kernel"
    done

    # --- PKGBUILD Modifications ---

    # Reset pkgrel
    #sed -i '/^pkgrel=/c\pkgrel=99' "$kernel/PKGBUILD"

    # Enable ZFS module build
    sed -i 's/: "${_build_zfs:=no}"/: "${_build_zfs:=yes}"/' "$kernel/PKGBUILD"

    # Set architecture optimization to zen4
    sed -i '/_processor_opt:=/ s/:=.*}/:=zen4}/' "$kernel/PKGBUILD"

    # Enable the "-lto" package suffix
    #sed -i 's/_use_lto_suffix:=no/_use_lto_suffix:=yes/' "$kernel/PKGBUILD"

    # Disable the "-gcc" package suffix
    #sed -i 's/_use_gcc_suffix:=yes/_use_gcc_suffix:=no/' "$kernel/PKGBUILD"

    # Add patch files to the source array BEFORE the closing parenthesis
    # This searches within the source=(...) block for the closing parenthesis ')'
    # and uses 'i\' to insert the lines before it.
    if ! grep -q "0001-amd-isp4-patch.patch" "$kernel/PKGBUILD"; then
        sed -i '/^source=(/,/)/{ /)/i\
    "0001-amd-isp4-patch.patch"\
    "0002-amd-isp4-patch.patch"\
    "0003-amd-isp4-patch.patch"\
    "0004-amd-isp4-patch.patch"\
    "0005-amd-isp4-patch.patch"\
    "0006-amd-isp4-patch.patch"\
    "0007-amd-isp4-patch.patch"
}' "$kernel/PKGBUILD"
        echo "Added patches to source array in $kernel/PKGBUILD"
    else
        echo "Patches already present in source array in $kernel/PKGBUILD"
    fi


    # Add Kconfig option to enable AMD_ISP4 module
    # Find the line 'cp ../config .config' and insert after it
    if ! grep -q "AMD_ISP4" "$kernel/PKGBUILD"; then
        sed -i '/cp ..\/config .config/a\
\
    # --- Enable AMD ISP4 Driver ---\
    echo "Enabling AMD ISP4 Driver..."\
    scripts\/config -m AMD_ISP4
' "$kernel/PKGBUILD"
        echo "Added AMD ISP4 Driver enablement to $kernel/PKGBUILD"
    else
        echo "AMD ISP4 Driver enablement already present in $kernel/PKGBUILD"
    fi

    # --- Update Checksums and .SRCINFO ---
    echo "Updating checksums and .SRCINFO for $kernel..."
    (cd "$kernel" && updpkgsums && makepkg --printsrcinfo > .SRCINFO)

    echo "Modifications complete for $kernel"
    echo "--------------------------------------------------"
done

echo "All kernel modifications complete."
