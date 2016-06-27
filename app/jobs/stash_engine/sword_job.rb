require 'stash/sword'

module StashEngine
  class SwordJob < ActiveJob::Base
    queue_as :default

    def log
      Delayed::Worker.logger
    end

    def client_for(sword_params)
      Stash::Sword::Client.new(logger: log, **sword_params)
    end

    def perform(doi:, zipfile:, resource_id:, sword_params:)
      log.debug("#{self.class}: doi: #{doi}, zipfile: #{zipfile}, resource_id: #{resource_id}, sword_params: #{sword_params}")
      request_msg = "Submitting #{zipfile} for #{doi}: #{(sword_params.map { |k, v| "#{k}: #{v}" }).join(', ')}"

      begin
        resource = Resource.find(resource_id)
        create_or_update(doi, zipfile, resource, sword_params)
        resource.update_version(zipfile)
        update_submission_log(resource_id: resource_id, request_msg: request_msg, response_msg: 'Success')
      rescue => e
        log.error(e)
        log.debug(e.backtrace.join("\n")) if e.backtrace
        update_submission_log(resource_id: resource_id, request_msg: request_msg, response_msg: "Failed: #{e}")
        raise

        # TODO: Enable this (and don't raise) once we have ExceptionNotifier configured
        # ExceptionNotifier.notify_exception(e, data: {doi: doi, zipfile: zipfile, resource_id: resource_id, sword_params: sword_params})
      end
    end

    def create_or_update(doi, zipfile, resource, sword_params)
      if resource.update_uri
        update(doi: doi, zipfile: zipfile, resource_id: self.id, sword_params: sword_params)
      else
        create(doi: doi, zipfile: zipfile, resource_id: self.id, sword_params: sword_params)
      end
    end

    def create(doi:, zipfile:, resource:, client:)
      log.debug("invoking create(doi: #{doi}, zipfile: #{zipfile}) for resource #{resource.id}")
      receipt = client.create(doi: doi, zipfile: zipfile)
      log.debug("create(doi: #{doi}, zipfile: #{zipfile}) for resource #{resource.id} completed with em_iri #{receipt.em_iri}, edit_iri #{receipt.edit_iri}")
      resource.download_uri = receipt.em_iri
      resource.update_uri = receipt.edit_iri
      resource.save # save download and update URLs for this resource
      log.debug("resource #{resource.id} saved")
    end

    def update(doi:, zipfile:, resource:, client:)
      update_uri = resource.update_uri
      log.debug("invoking update(edit_iri: #{update_uri}, zipfile: #{zipfile}) for resource #{resource.id}")
      status = client.update(edit_iri: update_uri, zipfile: zipfile)
      log.debug("update(edit_iri: #{update_uri}, zipfile: #{zipfile}) for resource #{resource.id} completed with status #{status}")
    end

    def update_submission_log(resource_id:, request_msg:, response_msg:)
      SubmissionLog.create(resource_id: resource_id, archive_submission_request: request_msg, archive_response: response_msg)
    end

  end
end
