Legacy storage symlinks were intoduced in openSUSE distributions in the past
either accidently or with boggus names and, for the latter case, were replaced
later by udev upstream with more accurate and stable names. Unfortunately some
systems might have been initialized with those incorrect names even though it is
less likely with (desktop) systems running Tumbleweed.

Given that Tumbleweed is a rolling release distribution moving fastly and
keeping track of the most recent versions of projects, we would like to drop as
much as specific code used to ensure backward compatibility that makes openSUSE
systemd diverge from its upstream counterpart project as we can't really
maintain such code forever.

Hence we provide this script aimed at helping users of Tumbleweed to figure out
whether their system is currently relying on legacy storage symlinks. If it is
the case, the script will notify the user and will list the places that will
need to be updated. The script doesn't take any option nor argument.

Please note that only `/etc/fstab` and `/etc/crypttab` configuration files are
checked at the moment. Therefore it might possible that some (custom) scripts
might still reference the obsolete symlinks. If you have such scripts, please
make sure to update your scripts too.

Another approach to verify that your system is not relying on the legacy
symlinks is to boot your system with `udev.compat_symlink_generation=0` option
appended to the kernel command line. If your system still behaves as expected
after some times then it likely means that your system is free from legacy
symlinks.

If you need further assistance, please open a bug at https://bugzilla.suse.com/
and assign it to `systemd-maintainers@suse.de`.

Thank you.
