#!/bin/bash
set -e

# Path da aplicação
APP_PATH=/var/www/html
SENTINEL_FILE=$APP_PATH/.krayin_installed

# --- 1. Aguardar Banco de Dados ---
echo "Aguardando o serviço de banco de dados..."
# netcat (nc) verifica a disponibilidade da porta 3306 do contêiner 'database'
until nc -z -v -w30 database 3306
do
  echo "Aguardando database..."
  sleep 1
done
echo "Banco de dados está pronto."

# --- 2. Configurações de Permissão (Repetível) ---
echo "Ajustando permissões de storage e cache..."
chown -R www-data:www-data $APP_PATH/storage $APP_PATH/bootstrap/cache
chmod -R 775 $APP_PATH/storage $APP_PATH/bootstrap/cache

# --- 3. Instalação de Primeira Vez (Protegida pelo Sentinela) ---
if; then
    echo "--- Executando instalação inicial do Krayin CRM ---"

    # Geração de APP_KEY (fundamental para segurança Laravel)
    echo "Gerando APP_KEY e rodando o comando de armazenamento..."
    php $APP_PATH/artisan key:generate --force
    php $APP_PATH/artisan storage:link

    # A Instalação Krayin CRM: usa as variáveis ADMIN_EMAIL e ADMIN_PASSWORD definidas no Coolify
    echo "Executando instalação do Krayin CRM de forma não interativa..."
    php $APP_PATH/artisan krayin-crm:install --force \
        --admin-email="$ADMIN_EMAIL" \
        --admin-password="$ADMIN_PASSWORD"

    # Limpar cache após instalação
    php $APP_PATH/artisan config:cache
    
    # Criação do arquivo sentinela
    touch $SENTINEL_FILE
    echo "Instalação inicial concluída. Sentinela criado."
else
    echo "Krayin já está instalado. Prosseguindo com migrações e otimizações."
    php $APP_PATH/artisan config:cache
fi

# --- 4. Executar Migrações (A cada deploy) ---
echo "Executando migrações de banco de dados (se houver)..."
php $APP_PATH/artisan migrate --force

# --- 5. Iniciar Processo Principal ---
# Inicia o PHP-FPM (processo que serve a aplicação web)
echo "Iniciando processo principal: exec $*"
exec "$@"