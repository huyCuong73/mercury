package integration

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/tests/integration/rpc/backend"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestBackend(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.IntegrationNetworkApp](CreateEvmd, "evm.IntegrationNetworkApp")
	s := backend.NewTestSuite(create)
	suite.Run(t, s)
}
