# Copyright 2020-present Open Networking Foundation
# SPDX-License-Identifier: LicenseRef-ONF-Member-Only-1.0

# PHONY definitions
RESET_CLEAN_PHONY			:= reset-oai reset-omec reset-atomix reset-onos-op reset-ric reset-oai-test reset-ransim-test reset-test clean clean-all

reset-oai:
	helm delete -n $(RIAB_NAMESPACE) oai-enb-cu || true
	helm delete -n $(RIAB_NAMESPACE) oai-enb-du || true
	helm delete -n $(RIAB_NAMESPACE) oai-ue || true
	rm -f $(M)/oai-enb-cu*
	rm -f $(M)/oai-enb-du
	rm -f $(M)/oai-ue

reset-omec:
	helm delete -n $(RIAB_NAMESPACE) omec-control-plane || true
	helm delete -n $(RIAB_NAMESPACE) omec-user-plane || true
	cd $(M); rm -f omec

reset-atomix:
	kubectl delete -f https://raw.githubusercontent.com/atomix/raft-storage-controller/master/deploy/raft-storage-controller.yaml || true
	kubectl delete -f https://raw.githubusercontent.com/atomix/cache-storage-controller/master/deploy/cache-storage-controller.yaml || true
	kubectl delete -f https://raw.githubusercontent.com/atomix/kubernetes-controller/master/deploy/atomix-controller.yaml || true
	cd $(M); rm -f atomix

reset-onos-op:
	kubectl delete -f https://raw.githubusercontent.com/onosproject/onos-operator/v0.4.0/deploy/onos-operator.yaml || true
	@until [ $$(kubectl get po -n kube-system -l name=topo-operator --no-headers | wc -l) == 0 ]; do sleep 1; done
	@until [ $$(kubectl get po -n kube-system -l name=config-operator --no-headers | wc -l) == 0 ]; do sleep 1; done
	cd $(M); rm -f onos-operator

reset-ric:
	helm delete -n $(RIAB_NAMESPACE) sd-ran || true
	@until [ $$(kubectl get po -n $(RIAB_NAMESPACE) -l app=onos --no-headers | wc -l) == 0 ]; do sleep 1; done
	cd $(M); rm -f ric

reset-oai-test: reset-omec reset-oai reset-ric

reset-ransim-test: reset-ric

reset-test: reset-oai-test reset-ransim-test reset-onos-op reset-atomix

clean: reset-test
	helm repo remove sdran || true
	kubectl delete po router || true
	kubectl delete net-attach-def core-net || true
	sudo ovs-vsctl del-br br-access-net || true
	sudo ovs-vsctl del-br br-core-net || true
	sudo apt remove --purge openvswitch-switch -y || true
	source "$(VENV)/bin/activate" && cd $(BUILD)/kubespray; \
	ansible-playbook --extra-vars "reset_confirmation=yes" -b -i inventory/local/hosts.ini reset.yml || true
	@if [ -d /usr/local/etc/emulab ]; then \
		mount | grep /mnt/extra/kubelet/pods | cut -d" " -f3 | sudo xargs umount; \
		sudo rm -rf /mnt/extra/kubelet; \
	fi
	rm -rf $(M)

clean-all: clean
	rm -rf $(CHARTDIR)