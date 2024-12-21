# Deployless

Spend less time configuring deployment for your Rails application no matter if you are using bare metal servers or cloud.

Start with creating configuration:

```bash
dpls init
```

Deploy given environment:

```bash
dpls production prepare
```

Connect to Rails console:

```bash
dpls production console
```

Update environments by updating `environment_variables` section in `.deployless.yml` for given environment and then invoking:

```bash
dpls production update-env
```
