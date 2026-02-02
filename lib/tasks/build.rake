# ref: https://github.com/rails/rails/issues/43906#issuecomment-1094380699
# https://github.com/rails/rails/issues/43906#issuecomment-1099992310
task before_assets_precompile: :environment do
  # In Docker builds, pnpm install already ran in the Dockerfile.
  # SKIP_PNPM_INSTALL_IN_RAKE=1 avoids a redundant install that wastes ~500 MB RAM.
  unless ENV['SKIP_PNPM_INSTALL_IN_RAKE']
    system('pnpm install')
  end
  system('echo "-------------- Building SDK for Production --------------"')
  system('pnpm run build:sdk')
  system('echo "-------------- Building App for Production --------------"')
end

# every time you execute 'rake assets:precompile'
# run 'before_assets_precompile' first
Rake::Task['assets:precompile'].enhance %w[before_assets_precompile]
