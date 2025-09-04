# Multi-Environment Terraform Deployment

Este documento explica cómo ejecutar `terraform apply` en múltiples environments con un solo comando.

## 🚀 Opciones Disponibles

### 1. Script Principal: `deploy-all-environments.sh`

El script más completo y flexible para deployments multi-environment.

```bash
# Desplegar todos los environments secuencialmente
./tools/deploy-all-environments.sh apply us-east-1

# Desplegar todos los environments en paralelo
PARALLEL_ENVIRONMENTS=true ./tools/deploy-all-environments.sh apply us-east-1

# Desplegar con auto-approve (sin confirmaciones)
AUTO_APPROVE=true ./tools/deploy-all-environments.sh apply us-east-1

# Desplegar en paralelo con auto-approve
AUTO_APPROVE=true PARALLEL_ENVIRONMENTS=true ./tools/deploy-all-environments.sh apply us-east-1

# Planificar todos los environments
./tools/deploy-all-environments.sh plan-all us-east-1

# Validar estructura de environments
./tools/deploy-all-environments.sh validate

# Destruir todos los environments (siempre secuencial por seguridad)
AUTO_APPROVE=true ./tools/deploy-all-environments.sh destroy us-east-1
```

### 2. Script Rápido: `quick-deploy-all.sh`

Script simplificado para casos de uso comunes.

```bash
# Desplegar todos los environments
./tools/quick-deploy-all.sh apply

# Desplegar en paralelo
./tools/quick-deploy-all.sh apply-parallel

# Desplegar con auto-approve
./tools/quick-deploy-all.sh apply-auto

# Desplegar en paralelo con auto-approve
./tools/quick-deploy-all.sh apply-auto-parallel

# Planificar todos
./tools/quick-deploy-all.sh plan

# Validar
./tools/quick-deploy-all.sh validate
```

### 3. Makefile Targets

Usando `make` para ejecutar deployments multi-environment.

```bash
# Desplegar todos los environments secuencialmente
make deploy-all-environments REGION=us-east-1

# Desplegar todos los environments en paralelo
make deploy-all-environments-parallel REGION=us-east-1

# Desplegar con auto-approve
make deploy-all-auto REGION=us-east-1

# Desplegar en paralelo con auto-approve
make deploy-all-auto-parallel REGION=us-east-1

# Planificar todos los environments
make plan-all-environments REGION=us-east-1

# Validar estructura
make validate-environments

# Destruir todos los environments
make destroy-all-environments REGION=us-east-1
```

### 4. Taskfile (si tienes Task instalado)

```bash
# Desplegar todos los environments
task deploy-all

# Desplegar en paralelo
task deploy-all-parallel

# Desplegar con auto-approve
task deploy-all-auto

# Desplegar en paralelo con auto-approve
task deploy-all-auto-parallel

# Planificar todos
task plan-all

# Validar
task validate

# Environments individuales
task deploy-dev
task deploy-stg
task deploy-prd
```

## 📋 Environments Procesados

Los scripts procesan automáticamente estos environments:
- **dev** (desarrollo)
- **stg** (staging/pruebas)
- **prd** (producción)

## ⚙️ Variables de Configuración

### Variables de Entorno

- `AUTO_APPROVE`: Saltar confirmaciones (`true`/`false`, default: `false`)
- `PARALLEL_ENVIRONMENTS`: Ejecutar environments en paralelo (`true`/`false`, default: `false`)
- `REGION`: Región de AWS (default: `us-east-1`)

### Ejemplos con Variables

```bash
# Cambiar región
REGION=us-west-2 ./tools/deploy-all-environments.sh apply

# Auto-approve + paralelo + región diferente
AUTO_APPROVE=true PARALLEL_ENVIRONMENTS=true REGION=eu-west-1 ./tools/deploy-all-environments.sh apply
```

## 🔍 Validación de Environments

Antes de ejecutar deployments, puedes validar que todos los directorios necesarios existen:

```bash
./tools/deploy-all-environments.sh validate
# o
make validate-environments
```

## 🚨 Consideraciones de Seguridad

### Ejecución Secuencial vs Paralela

- **Secuencial**: Más seguro, permite revisar cada environment antes del siguiente
- **Paralela**: Más rápido, pero todos los environments se despliegan simultáneamente

### Destroy Operations

Las operaciones de `destroy` siempre se ejecutan secuencialmente por seguridad, independientemente de la configuración de `PARALLEL_ENVIRONMENTS`.

## 📊 Orden de Ejecución

Cada environment sigue el orden de dependencias definido en `deploy-ordered.sh`:

1. **Governance Layer**
   - Providers
   - IAM
   - Organization

2. **Core Layer**
   - Networking
   - Security
   - Routing

3. **Services Layer**
   - Databases
   - Caching
   - Messaging
   - CI/CD

4. **Applications Layer**
   - App-1
   - App-2

## 🛠️ Troubleshooting

### Error: Environment directory missing

Si ves errores como "Environment directory missing", necesitas crear los directorios faltantes:

```bash
# Crear directorios faltantes para staging
mkdir -p core/security/stg_us-east-1
mkdir -p core/routing/stg_us-east-1

# Crear directorios faltantes para producción
mkdir -p core/security/prd_us-east-1
mkdir -p core/routing/prd_us-east-1
```

### Logs y Debugging

Los scripts proporcionan logs detallados con códigos de color:
- 🔵 **INFO**: Información general
- 🟢 **SUCCESS**: Operaciones exitosas
- 🟡 **WARNING**: Advertencias
- 🔴 **ERROR**: Errores

## 📝 Ejemplos Completos

### Deployment Completo de Desarrollo a Producción

```bash
# 1. Validar primero
./tools/deploy-all-environments.sh validate

# 2. Planificar todos los environments
./tools/deploy-all-environments.sh plan-all us-east-1

# 3. Desplegar secuencialmente (más seguro)
./tools/deploy-all-environments.sh apply us-east-1

# 4. O desplegar en paralelo (más rápido)
PARALLEL_ENVIRONMENTS=true ./tools/deploy-all-environments.sh apply us-east-1
```

### Deployment Automatizado (CI/CD)

```bash
# Para pipelines automatizados
AUTO_APPROVE=true PARALLEL_ENVIRONMENTS=true ./tools/deploy-all-environments.sh apply us-east-1
```

### Cleanup Completo

```bash
# Destruir todos los environments
AUTO_APPROVE=true ./tools/deploy-all-environments.sh destroy us-east-1
```

## 🎯 Comando Más Simple

**Para el caso de uso más común (desplegar todos los environments secuencialmente):**

```bash
./tools/quick-deploy-all.sh apply
```

**Para despliegue rápido en paralelo con auto-approve:**

```bash
./tools/quick-deploy-all.sh apply-auto-parallel
```