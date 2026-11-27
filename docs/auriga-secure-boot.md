# Auriga Limine migration and Secure Boot

Auriga uses Limine in UEFI mode with ten NixOS generations and a Windows 11
entry. Signing is initially disabled. Configuration enrollment, boot file
checksums, and fatal checksum failures are enabled; the boot entry editor is
disabled. These settings prepare the boot chain for Secure Boot but do not
authenticate it until signing and firmware enforcement are enabled.

## Install and test Limine

Run from this repository on auriga, with firmware Secure Boot disabled:

```sh
nix build .#nixosConfigurations.auriga.config.system.build.toplevel
sudo nixos-rebuild boot --flake .#auriga
efibootmgr -v
```

Check that the new `Limine` firmware entry points to
`\EFI\limine\BOOTX64.EFI` on the Linux ESP (`/boot`, UUID `A83B-8EAC`).
Reboot and select Limine. Test both NixOS and Windows before proceeding.
If firmware keeps selecting `UEFI OS` or `Linux Boot Manager`, select Limine
in firmware setup and move it first in the boot order. The old fallback
`\EFI\BOOT\BOOTX64.EFI` is not updated by this configuration.

Windows is chainloaded from the ESP currently at `/dev/nvme0n1p4`, GPT GUID
`86ef0529-a0f7-48fe-b02d-893257eafa8f`. This matches the existing Windows Boot
Manager firmware entry and avoids relying on changing disk numbers or `FS2`.

## Prepare keys and sign Limine

Before changing firmware keys, save any Windows BitLocker or Device Encryption
recovery key and suspend protection if enabled. Keep a NixOS installer USB
available and back up `/boot` outside the ESP.

After booting the new generation, inspect the state and create keys if none
already exist:

```sh
sudo sbctl status
sudo sbctl create-keys
```

Keep a protected backup of `/var/lib/sbctl`. Private keys belong there, never in
this repository or the Nix store. Reuse existing keys if already provisioned.

Change `boot.loader.limine.secureBoot.enable` to `true` in
`hosts/auriga/configuration.nix`, then install and verify the signed loader
while firmware Secure Boot remains disabled:

```sh
sudo nixos-rebuild boot --flake .#auriga
sudo sbctl verify /boot/efi/limine/BOOTX64.EFI
```

Require successful signature verification before enabling firmware enforcement.
The module enrolls the generated configuration hash and signs Limine on every
bootloader installation. Do not edit `/boot/limine/limine.conf` manually afterward;
change Nix configuration and rebuild instead.

## Enroll keys and enable firmware enforcement

Enter firmware setup and put Secure Boot into Setup Mode using the vendor's
key management controls. Merely disabling Secure Boot is not Setup Mode.
Boot NixOS through Limine again, confirm Setup Mode, then enroll:

```sh
sudo sbctl status
sudo sbctl enroll-keys --microsoft --firmware-builtin
sudo sbctl list-enrolled-keys
sudo sbctl verify /boot/efi/limine/BOOTX64.EFI
```

The enrollment includes Microsoft and firmware default certificates to support
Windows and vendor firmware. If enrollment reports an error, resolve it before
continuing; do not bypass its checks. Automatic key generation and enrollment
remain disabled in the Nix configuration.

Enable Secure Boot in firmware, keep Limine first in the boot order, and reboot:

```sh
sudo sbctl status
bootctl status
```

Confirm Secure Boot is enabled and Setup Mode is disabled. Test Windows again,
then resume any suspended encryption protection. Limine verifies the NixOS
boot files against the enrolled configuration; firmware verifies the Windows
EFI executable. Separate signatures on each NixOS kernel/initrd are not the
verification mechanism here.

## Recovery

If a signed boot fails, disable Secure Boot in firmware and select Limine or
the previous Linux Boot Manager entry. Older systemd-boot files are not managed
by future Limine rebuilds, so they are only a temporary recovery option.
An older NixOS generation selected inside Limine still uses Limine; it does not
restore systemd-boot by itself.

To restore systemd-boot permanently, revert the bootloader block to its previous
configuration and run `sudo nixos-rebuild boot --install-bootloader --flake
.#auriga` with Secure Boot disabled. If neither loader works, boot the installer
USB, mount the root filesystem and ESP, and use `nixos-enter` to rebuild.

References: [NixOS Limine module](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/system/boot/loader/limine/limine.nix),
[Limine configuration reference](https://github.com/Limine-Bootloader/Limine/blob/v12.x/CONFIG.md),
and [sbctl manual](https://github.com/Foxboron/sbctl/blob/master/docs/sbctl.8.txt).
