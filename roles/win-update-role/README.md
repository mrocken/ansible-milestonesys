Milestone-win-update
=========
This is a WORK IN PROGRESS.
This role is designed to automate the updating of a milestone CCTV server.


Requirements
------------

The role will require MilestonePSTools found here https://www.powershellgallery.com/packages/MilestonePSTools/1.0.69 


Role Variables
--------------
host vars include the winRM setting using certificates. This can be changed to match your authentication method. There is also the site-email-1: var for emailing the sites after a sucessful update



Example Playbook
----------------

---
- hosts: all
  gather_facts: false
  
  roles: win-update-role


License
-------

gnu v3.0

Author Information
------------------

mrocken89@gmail.com 
