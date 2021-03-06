{#- Set the name of the winrepo package. -#}
{%- set name = 'dotnet' -%}

{#-
Define variables that may be unique to the system and are required for one of
the winrepo parameters.
-#}
{%-
set systemroot = salt['reg.read_value'](
    'HKEY_LOCAL_MACHINE',
    'SOFTWARE\Microsoft\Windows NT\CurrentVersion',
    'SystemRoot').vdata
-%}

{#-
Define a dictionary of versions with variables that are distinct for each
version.
-#}
{%- load_yaml as versions %}
4.6.01590:
  full_name: 'Microsoft .NET Framework 4.6.2'
  filename: 'NDP462-KB3151800-x86-x64-AllOS-ENU.exe'
4.6.01055:
  full_name: 'Microsoft .NET Framework 4.6.1'
  filename: 'NDP461-KB3102436-x86-x64-AllOS-ENU.exe'
4.6.00081:
  full_name: 'Microsoft .NET Framework 4.6'
  filename: 'NDP46-KB3045557-x86-x64-AllOS-ENU.exe'
4.5.51209:
  full_name: 'Microsoft .NET Framework 4.5.2'
  filename: 'NDP452-KB2901907-x86-x64-AllOS-ENU.exe'
{% endload %}

{#-
Initialize the `package` dictionary, which will contain the information needed
for the winrepo package definition. This dictionary is structured so that the
jinja content can be separated into another file, and this single variable can
be imported into an accompanying winrepo sls file.
-#}
{%- load_yaml as package -%}
name: {{ name }}
pillar: '{{ name }}:winrepo'
{# `common_params` are winrepo params that are the same for all versions. #}
common_params:
  reboot: False
  install_flags: ' /q /norestart'
  msiexec: False
  uninstall_flags: ' /uninstall /x86 /x64 /q /norestart'
{# `versions` are winrepo params that are distinct per version. #}
versions:
  {% for version,params in versions.items() %}
  '{{ version }}':
    installer: >-
      https://s3.amazonaws.com/systemprep-repo/windows/dotnet/{{
      version }}/{{ params.filename }}
    full_name: {{ params.full_name }}
    uninstaller: >-
      {{ systemroot }}\Microsoft.NET\Framework64\v4.0.30319\SetupCache\v{{
      version }}\Setup.exe
  {% endfor %}
{%- endload -%}

{#-
Update and merge the `package.versions` dictionary with winrepo version
settings from pillar.
-#}
{%-
do package.versions.update(salt['pillar.get'](
    package.pillar ~ ':versions',
    default=package.versions,
    merge=True))
-%}

{#-
Create the winrepo state definition, looping over the versions and merging in
the `package.common_params` dictionary.
-#}
{{ package.name }}:
  {%- for version,params in package.versions.items() %}
  {%- do params.update(salt['pillar.get'](
      package.pillar ~ ':common_params',
      default=package.common_params,
      merge=True)) %}
  '{{ version }}':
    {{ params }}
  {%- endfor %}
