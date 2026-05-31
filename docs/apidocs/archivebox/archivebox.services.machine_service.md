# {py:mod}`archivebox.services.machine_service`

```{py:module} archivebox.services.machine_service
```

```{autodoc2-docstring} archivebox.services.machine_service
:allowtitles:
```

## Module Contents

### Classes

````{list-table}
:class: autosummary longtable
:align: left

* - {py:obj}`MachineService <archivebox.services.machine_service.MachineService>`
  -
````

### API

`````{py:class} MachineService(bus)
:canonical: archivebox.services.machine_service.MachineService

Bases: {py:obj}`abx_dl.services.base.BaseService`

````{py:attribute} LISTENS_TO
:canonical: archivebox.services.machine_service.MachineService.LISTENS_TO
:value: >
   None

```{autodoc2-docstring} archivebox.services.machine_service.MachineService.LISTENS_TO
```

````

````{py:attribute} EMITS
:canonical: archivebox.services.machine_service.MachineService.EMITS
:value: >
   []

```{autodoc2-docstring} archivebox.services.machine_service.MachineService.EMITS
```

````

````{py:method} on_MachineEvent__save_to_db(event: abx_dl.events.MachineEvent) -> None
:canonical: archivebox.services.machine_service.MachineService.on_MachineEvent__save_to_db
:async:

```{autodoc2-docstring} archivebox.services.machine_service.MachineService.on_MachineEvent__save_to_db
```

````

`````
