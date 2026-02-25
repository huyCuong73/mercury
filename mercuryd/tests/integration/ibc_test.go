package integration

import (
	"testing"

	"github.com/stretchr/testify/suite"

	evm "github.com/huyCuong73/mercury"
	"github.com/huyCuong73/mercury/tests/integration/x/ibc"
	testapp "github.com/huyCuong73/mercury/testutil/app"
)

func TestIBCKeeperTestSuite(t *testing.T) {
	create := testapp.ToEvmAppCreator[evm.IBCIntegrationApp](CreateEvmd, "evm.IBCIntegrationApp")
	s := ibc.NewKeeperTestSuite(create)
	suite.Run(t, s)
}
