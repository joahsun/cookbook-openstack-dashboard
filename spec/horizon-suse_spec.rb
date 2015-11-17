# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-dashboard::horizon' do
  describe 'suse' do
    let(:runner) { ChefSpec::SoloRunner.new(SUSE_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge('openstack-dashboard::server')
    end

    include_context 'non_redhat_stubs'
    include_context 'dashboard_stubs'

    context 'mysql backend' do
      include_context 'mysql_backend'

      it 'installs mysql packages when mysql backend is configured' do
        expect(chef_run).to upgrade_package('python-mysql')
      end
    end

    it 'installs nuage packages if dashboard nuage customization module is enabled' do
      node.set['openstack']['dashboard']['nuage']['customization_module']['enabled'] = true
      expect(chef_run).to install_package('nuage-openstack-horizon')
    end

    describe 'local_settings.py' do
      let(:file) { chef_run.template('/srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py') }

      it 'does not have urls set' do
        [
          /^LOGIN_URL =$/,
          /^LOGOUT_URL =$/,
          /^LOGIN_REDIRECT_URL =$/
        ].each do |line|
          expect(chef_run).to_not render_file(file.name).with_content(line)
        end
      end
    end

    context 'postgresql backend' do
      include_context 'postgresql_backend'
      let(:file) { chef_run.template('/srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py') }

      it 'installs packages' do
        expect(chef_run).to upgrade_package('openstack-dashboard')
      end

      it 'installs postgresql packages' do
        expect(chef_run).to upgrade_package('python-psycopg2')
      end

      it 'creates local_settings.py' do
        expect(chef_run).to render_file(file.name).with_content('autogenerated')
      end

      it 'does not execute openstack-dashboard syncdb by default' do
        cmd = 'python manage.py syncdb --noinput'
        expect(chef_run).not_to run_execute(cmd).with(
          cwd: '/srv/www/openstack-dashboard',
          environment: {
            'PYTHONPATH' => '/etc/openstack-dashboard:' \
                            '/srv/www/openstack-dashboard:' \
                            '$PYTHONPATH'
          }
        )
      end
    end
  end
end
