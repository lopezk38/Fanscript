Fanscript, a simple bash script for managing fan speeds through lm-sensors files

Depends on lm-sensors

Created because the fancontrol package was not compatible with my old Dell workstation. Should work on any system by pointing some of the variables to the right file locations

Uses an x^2 fan curve. Different mathematical functions can be substituted to achive different curves (or linear), but are not included at this time

Intended to be ran as a systemctl service, but can be run in a regular shell for debugging or testing fan curves with the self test mode enabled

To install:
	Copy the service file to /etc/systemd/system/
	Copy the .sh file to /usr/bin/
	Make sure the .sh file has execute permissions
	Run systemctl start fanscript.service
	If you want to run the script at boot, run systemctl enable fanscript.service
