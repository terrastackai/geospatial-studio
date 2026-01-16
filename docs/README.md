# IBM Geospatial Exploration and Orchestration Studio Docs

This section has the documentation for the IBM Geospatial Exploration and Orchestration Studio.

## To update docs page

1. Install [hatch](https://hatch.pypa.io/1.9/install/#command-line-installer) in your workstation
2. Change to the docs directory, create hatch environment and enter the environment created:
```sh
$ hatch env create
$ hatch shell
``` 
2. Make changes
3. To serve locally run `hatch run serve` and to build run `hatch run build`
4. Commit and push changes to github
5. Run the following command: `hatch run gh-deploy` and it will push github pages site.

## Live preview

### From the terminal

```bash
hatch run serve
```

NB: Run all commands from the docs directory of this repo

