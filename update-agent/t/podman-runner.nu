#!/usr/bin/env nu
# Allows running tests inside of podman.
# If nu shell is not there, install it: 'cargo install --locked nu'

## TODO how to cleanup the temp directory?
def populate-mock-efivars [] {
	let d = (mktemp --directory)
	0x[06 00 00 00 00 00 00 00] | save $"($d)/BootChainFwCurrent-781e084c-a330-417c-b678-38e696380cb9" --raw
	0x[07 00 00 00 00 00 00 00] | save $"($d)/RootfsStatusSlotB-781e084c-a330-417c-b678-38e696380cb9" --raw

	return $d
}

# NOTE: only works if built with 'cargo build --features skip-manifest-signature-verification'

def main [prog, args] {
	let absolute_path = ($prog | path expand)

	let mock_efivars = populate-mock-efivars

	# TODO add overlay for persistent
	(podman run
	 --rm
	 -v $"($absolute_path):/mnt/program:Z"
	 -w /mnt
	 --security-opt=unmask=/sys/firmware
	 --security-opt=mask=/sys/firmware/acpi:/sys/firmware/dmi:/sys/firmware/memmap
	 --mount=type=bind,src=($mock_efivars),dst=/sys/firmware/efi/efivars/,rw,relabel=shared,unbindable
	 --mount=type=bind,src=./orb_update_agent.conf,dst=/etc/orb_update_agent.conf,relabel=shared,ro
	 --mount=type=bind,src=./mock-usr-persistent,dst=/usr/persistent/,ro,relabel=shared
	 --mount=type=bind,src=./claim.json,dst=/mnt/claim.json,ro,relabel=shared
	 --mount=type=bind,src=./s3_bucket,dst=/mnt/s3_bucket/,ro,relabel=shared
	 --mount=type=tmpfs,dst=/mnt/updates/
	 -e RUST_BACKTRACE
	 -it fedora:latest)

#
#	 -v $"($mock_efivars):/tmp/firmware/:O"
#	 --mount=type=bind,src=($mock_efivars),dst=/sys/firmware/,ro,relabel=shared,unbindable

}
