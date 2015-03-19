# SIMS.NetToActiveDirectory

An automated system to create pupil network accounts, and ensure that each account's details and permissions always reflect the settings in the school's management system.

User accounts created by this script have a samAccountName set to the pupil's SIMS .Net admission number (sans leading zeros), and have an initial password of `password`.

## Script Customization
This script is specific to Stowmarket Middle School and MUST be customized before being used in any other establishment.

### Minimum Changes Necessary

* All LDAP Distinguished Names must have `DC=stowmarketmiddle,DC=suffolk,DC=sch,DC=uk` replaced with the school's own domain root.
* Pupil UPNs contain Stowmarket Middle School's domain name, this should be updated to the domain name of the implementing school.
* The script expects to handle pupils from year 5 onwards. If your school does not cater to year 5 pupils and older, the integers in the `year_of_entry` and `year_group` functions must be updated to more meaningful values.
* The script assumes that the school is using a Samba fileserver called wildfire, and that all user home directories are accessible under the special `homes` share. This `magic` share automatically allows access to the home directory of the currently authenticating user. If this does not match your setup, the home directory value (line 148) will need to be adjusted.
* As the file server is expected to be running some form of *nix, file server prep is performed by a bash script called via SSH (line 153). If this is not true for your file server/NAS/SAN, this will need to be replaced with something more appropriate.

## SIMS .Net Settings
To properly assign pupils/students to the correct AD groups, SIMS .Net must be configured to store the relevant information in an easily accessible way. At Stowmarket Middle School, we use the `Parental Consent` and `User Defined Fields` features of the pupil records.

### Parental Consent

#### Internet Access
If this field is checked for a pupil, that pupil will be added to the `InternetAuthStudents` group, which can be used to restrict/prevent Internet access for pupils who lack their parent's consent. How this is done will depend on what systems individual schools have in place.

### User Defined Fields

#### Internet Ban
Checking this field will override the value of the `Internet Access` Parental Consent field and will ensure the pupil is not a member of the `InternetAuthStudents` AD group.

#### Computer Ban
Checking this field will cause the pupil's account to be disabled, preventing any use of the school's computer systems. NOTE: The code for this feature is currently disabled as it has not received sufficient testing (our pupils very rarely get banned so testing opportunities are rare).

#### Pupil Librarian
Checking this field will add the pupil to the `Pupil_Librarians` AD group, which can then be used to provide higher level access to the school's library management system, assuming the LMS integrates with AD.

## SIMS .Net Report
If you adhere to the SIMS .Net Settings above, you can use the report definition included with this script to extract the relevant data from SIMS .Net.

## Disclaimer

This script is provided AS IS, neither I, nor my employer will accept any responsibility for any problems this causes. If you do not understand the content of the script, and can not adapt it for your own situation, DO NOT USE IT.
