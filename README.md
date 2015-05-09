# PPWCode.Build.Tools

This repository is part of the PPWCode project and contains tools to assist building the code contained in the .NET PPWCode project.


## PPWCode PowerShell module

This is a PowerShell module that provides a couple of helper cmdlets for building and releasing PPWCode .NET libraries.


## Contributors

See the [GitHub Contributors list].


## PPWCode

This repository is part of the PPWCode project, developed by [PeopleWare n.v.].

More information can be found in the following locations:
* [PPWCode project website]
* [PPWCode Google Code website]

Please note that not all information on those sites is up-to-date. We are
currently in the process of moving the code away from the Google code
subversion repositories to git repositories on [GitHub].


### PPWCode .NET

Specifically for the .NET libraries: new development will be done on the
[PeopleWare GitHub repositories], and new stable releases will also
be published as packages on the [NuGet Gallery].

We believe in Design By Contract and have good experience with
[Microsoft Code Contracts] and the related tooling.  As such, our packages
always include Contract Reference assemblies.  This allows you to also
benefit as a user from the contracts that are already included in the
library code.

The packages also include both the pdb and xml files, for debugging symbols
and documentation respectively.  In the future we might look into using
symbol servers.


## License and Copyright

Copyright 2015 by [PeopleWare n.v.].

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.



[PPWCode project website]: http://www.ppwcode.org
[PPWCode Google Code website]: http://ppwcode.googlecode.com

[PeopleWare n.v.]: http://www.peopleware.be/

[NuGet]: https://www.nuget.org/
[NuGet Gallery]: https://www.nuget.org/policies/About

[GitHub]: https://github.com
[PeopleWare GitHub repositories]: https://github.com/peopleware

[Microsoft Code Contracts]: http://research.microsoft.com/en-us/projects/contracts/

[GitHub Contributors list]: https://github.com/peopleware/net-ppwcode-util-oddsandends/graphs/contributors

